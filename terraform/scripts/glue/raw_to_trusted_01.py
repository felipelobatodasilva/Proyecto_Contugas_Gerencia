import sys
import os
import logging             # <--- importa logging nativo
import boto3
import pandas as pd
import holidays
from datetime import datetime

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions  # <--- apenas getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# --- Configuración del logging estándar de Python ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)          # <--- usa logging.getLogger

# --- Buckets ---
RAW_BUCKET     = "contugas-raw-data-dev"
TRUSTED_BUCKET = "contugas-trusted-data-dev"

class ContugasPipeline:
    """
    Pipeline que replica el resultado del script pandas original,
    pero corriendo en Glue + Spark y guardando en Parquet con save_to_trusted().
    """

    def __init__(self, glue_context):
        self.glue_context = glue_context
        self.spark       = glue_context.spark_session
        self.data        = None
        self.percentis   = None

    def load_and_compute_percentis(self):
        """
        1) Baja el Excel de S3
        2) Lee con pandas y concatena sheets
        3) Calcula p10 y p90 con pandas.quantile (exacto)
        4) Convierte both pandas DataFrames a Spark DataFrames
        """
        s3 = boto3.client('s3')
        key_in = "Contugas_Datos.xlsx"
        tmp_path = "/tmp/data.xlsx"

        logger.info(f"Descargando s3://{RAW_BUCKET}/{key_in} → {tmp_path}")
        s3.download_file(RAW_BUCKET, key_in, tmp_path)

        # pandas: lectura y concatenación
        xls = pd.ExcelFile(tmp_path)
        dfs = []
        for sheet in xls.sheet_names:
            df = pd.read_excel(tmp_path, sheet_name=sheet)
            df["Cliente"] = sheet
            dfs.append(df)
        pdf = pd.concat(dfs, ignore_index=True)
        os.remove(tmp_path)
        logger.info(f"Pandas: total registros = {len(pdf)}")

        # pandas: cálculo exacto de percentiles por cliente
        pct = (
            pdf
            .groupby("Cliente")["Volumen"]
            .quantile([0.1, 0.9])
            .unstack()
            .reset_index()
            .rename(columns={0.1: "p10", 0.9: "p90"})
        )

        # Spark DataFrames
        self.data      = self.spark.createDataFrame(pdf)
        self.percentis = self.spark.createDataFrame(pct)

    def preprocess(self):
        """
        - Selecciona columnas
        - to_timestamp en Fecha
        - drop nulos
        - extrae Mes (int) y Año (int)
        """
        df = self.data
        df = df.select("Fecha", "Presion", "Temperatura", "Volumen", "Cliente")
        df = df.withColumn("Fecha", F.to_timestamp("Fecha"))
        df = df.na.drop(subset=["Fecha", "Presion", "Temperatura", "Volumen", "Cliente"])
        df = df.withColumn("Mes", F.month("Fecha"))
        df = df.withColumn("Año", F.year("Fecha"))
        self.data = df

    def smooth_variability(self, window=7):
        """
        Suaviza la variabilidad de Presion con media móvil centrada.
        """
        df = self.data
        w = Window.orderBy("Fecha").rowsBetween(-window//2, window//2)
        df = df.withColumn("Presion_Suavizada", F.avg("Presion").over(w))
        self.data = df

    def add_holidays(self):
        """
        Añade columna Es_Feriado usando holidays.Peru en los años presentes.
        """
        df = self.data
        anos = [int(x) for x in df.select(F.collect_set("Año")).first()[0]]
        feriados = holidays.Peru(years=anos)
        dates = [(d.strftime("%Y-%m-%d"),) for d in feriados.keys()]
        hol_df = self.spark.createDataFrame(dates, ["holiday_date"])

        df = df.withColumn("fecha_str", F.date_format("Fecha", "yyyy-MM-dd"))
        df = df.join(hol_df, df.fecha_str == hol_df.holiday_date, "left") \
               .withColumn("Es_Feriado", F.when(F.col("holiday_date").isNotNull(), True).otherwise(False)) \
               .drop("holiday_date", "fecha_str")
        self.data = df

    def categorize_volume_by_client(self):
        """
        Aplica regla exacta:
        'Anómalo' si Volumen < p10 o > p90; else 'Normal'.
        """
        df = self.data.join(self.percentis, on="Cliente", how="left")
        df = df.withColumn(
                "Anomalia",
                F.when((F.col("Volumen") < F.col("p10")) | (F.col("Volumen") > F.col("p90")),
                       F.lit("Anómalo"))
                 .otherwise(F.lit("Normal"))
            ) \
            .withColumn(
                "Anomalia_bin",
                F.when(F.col("Anomalia") == "Anómalo", 1).otherwise(0)
            )
        self.data = df

    def save_to_trusted(self):
        """
        Guarda los datos procesados en el bucket trusted en formato Parquet.
        """
        try:
            logger.info("Guardando datos procesados")
            
            if self.data.count() == 0:
                raise ValueError("No hay datos para guardar")
            
            # Crear ruta base
            output_path = f"s3://{TRUSTED_BUCKET}/dato_procesado"
            logger.info(f"Guardando en: {output_path}")
            
            # Añadir fecha de procesamiento
            self.data = self.data.withColumn(
                "fecha_procesamiento",
                F.date_format(F.current_timestamp(), "yyyy-MM-dd")
            )
            
            # Primero, renombrar las columnas existentes a minúsculas
            for col in self.data.columns:
                self.data = self.data.withColumnRenamed(col, col.lower())
            
            # Logs informativos
            logger.info("Columnas después de renombrar:")
            logger.info(self.data.columns)
            logger.info("Muestra de los datos antes de guardar:")
            self.data.select('anomalia').show()
            
            # Convertir a DynamicFrame y guardar
            dynamic_frame = DynamicFrame.fromDF(self.data, self.glue_context, "processed_data")
            self.glue_context.write_dynamic_frame.from_options(
                frame=dynamic_frame,
                connection_type="s3",
                connection_options={
                    "path": output_path,
                    "partitionKeys": ["fecha_procesamiento"]
                },
                format="parquet"
            )
            
            logger.info("Datos guardados con éxito y particionados por fecha_procesamiento")
            
        except Exception as e:
            logger.error(f"Error al guardar datos: {str(e)}")
            raise

    def run(self):
        self.load_and_compute_percentis()
        self.preprocess()
        self.smooth_variability()
        self.add_holidays()
        self.categorize_volume_by_client()
        self.save_to_trusted()


def run_pipeline():
    args = getResolvedOptions(sys.argv, ["JOB_NAME"])
    sc = SparkContext()
    glue_ctx = GlueContext(sc)
    job     = Job(glue_ctx)
    job.init(args["JOB_NAME"], args)

    pipeline = ContugasPipeline(glue_ctx)
    pipeline.run()

    job.commit()


if __name__ == "__main__":
    run_pipeline()