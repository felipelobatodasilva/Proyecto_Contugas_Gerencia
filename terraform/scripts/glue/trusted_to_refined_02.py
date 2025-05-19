import sys
import os
import logging
import boto3
import joblib
import pandas as pd

from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import StructType, StructField, IntegerType
from pyspark.sql.functions import pandas_udf, PandasUDFType

from awsglue.context     import GlueContext
from awsglue.job         import Job
from awsglue.utils       import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame

# ─── Configurações ─────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TRUSTED_BUCKET = "contugas-trusted-data-dev"
REFINED_BUCKET = "contugas-refined-data-dev"
NUM_CLUSTERS   = 5
MODEL_PREFIX   = "models"

class RefinedPipeline:
    def __init__(self, glue_context):
        self.glue  = glue_context
        self.spark = glue_context.spark_session
        self.data  = None

    def load_latest_data(self):
        dyf = self.glue.create_dynamic_frame.from_options(
            "s3",
            {"paths": [f"s3://{TRUSTED_BUCKET}/dato_procesado"]},
            "parquet"
        )
        df = dyf.toDF() \
                .dropna(subset=["cliente","presion","temperatura","volumen"]) \
                .cache()
        logger.info(f"[Validação] Linhas lidas sem NAs: {df.count()}")
        self.data = df
        return self

    def apply_original_models(self):
        summary = (
            self.data
                .groupBy("cliente")
                .agg(
                    F.mean("presion").alias("presion_med"),
                    F.mean("temperatura").alias("temp_med"),
                    F.mean("volumen").alias("vol_med")
                )
        )
        summary_pd = summary.toPandas()

        # baixa e carrega os modelos já treinados
        tmp = "/tmp/models"
        os.makedirs(tmp, exist_ok=True)
        s3 = boto3.client("s3")
        s3.download_file(REFINED_BUCKET, f"{MODEL_PREFIX}/scaler.joblib",      f"{tmp}/scaler.joblib")
        s3.download_file(REFINED_BUCKET, f"{MODEL_PREFIX}/kmeans_model.joblib", f"{tmp}/kmeans_model.joblib")
        scaler = joblib.load(f"{tmp}/scaler.joblib")
        kmeans = joblib.load(f"{tmp}/kmeans_model.joblib")

        # aplica scaler + kmeans
        X = summary_pd[["presion_med","temp_med","vol_med"]].values
        summary_pd["cluster"] = kmeans.predict(scaler.transform(X))
        logger.info("Clusters previstos com o modelo original")

        spark_summary = self.spark.createDataFrame(summary_pd[["cliente","cluster"]])
        self.data = self.data.join(spark_summary, on="cliente", how="inner")
        return self

    def proxy_anomaly(self):
        out_schema = StructType(self.data.schema.fields + [
            StructField("anomalia_proxy_cluster", IntegerType(), False)
        ])

        @pandas_udf(out_schema, PandasUDFType.GROUPED_MAP)
        def flag_proxy(pdf: pd.DataFrame) -> pd.DataFrame:
            for feat in ["presion","temperatura","volumen"]:
                p10 = pdf[feat].quantile(0.1)
                p90 = pdf[feat].quantile(0.9)
                pdf[f"a_{feat}"] = ((pdf[feat] < p10) | (pdf[feat] > p90)).astype(int)
            pdf["anomalia_proxy_cluster"] = pdf[
                [f"a_{f}" for f in ["presion","temperatura","volumen"]]
            ].max(axis=1)
            return pdf.drop(columns=[f"a_{f}" for f in ["presion","temperatura","volumen"]])

        self.data = self.data.groupby("cluster").apply(flag_proxy)
        return self

    def save(self):
        # adiciona a coluna de data de processamento
        out = self.data.withColumn(
            "fecha_procesamiento",
            F.date_format(F.current_timestamp(), "yyyy-MM-dd")
        )

        # converte e grava particionado
        dyf = DynamicFrame.fromDF(out, self.glue, "refined")
        self.glue.write_dynamic_frame.from_options(
            frame              = dyf,
            connection_type    = "s3",
            connection_options = {
                "path": f"s3://{REFINED_BUCKET}/dato_refinado",
                "partitionKeys": ["fecha_procesamiento"]
            },
            format             = "parquet"
        )
        logger.info("Dados refinados salvos em Parquet particionado por fecha_procesamiento")
        return self

def run_pipeline():
    args  = getResolvedOptions(sys.argv, ['JOB_NAME'])
    spark = SparkSession.builder.appName(args['JOB_NAME']).getOrCreate()
    glue  = GlueContext(spark.sparkContext)
    job   = Job(glue)
    job.init(args['JOB_NAME'], args)

    (RefinedPipeline(glue)
        .load_latest_data()
        .apply_original_models()
        .proxy_anomaly()
        .save()
    )

    job.commit()
    logger.info("Pipeline Glue concluído com sucesso")

if __name__ == "__main__":
    run_pipeline()
