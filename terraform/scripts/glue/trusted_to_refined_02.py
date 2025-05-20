import sys
import os
import logging
import boto3
import joblib
import pandas as pd

from pyspark.sql import SparkSession, functions as F, Window
from pyspark.sql.types import *
from pyspark.sql.functions import pandas_udf, PandasUDFType, col
from awsglue.context     import GlueContext
from awsglue.job         import Job
from awsglue.utils       import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame

from sklearn.preprocessing import StandardScaler
from sklearn.cluster       import KMeans

# ─── Configuração ─────────────────────────────────────────────────────────────
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

    def load_and_enrich(self):
        # 1) Lê Parquet "trusted"
        dyf = self.glue.create_dynamic_frame.from_options(
            "s3", {"paths":[f"s3://{TRUSTED_BUCKET}/dato_procesado"]}, "parquet"
        )
        df = dyf.toDF().withColumn("fecha", F.col("fecha").cast("timestamp"))

        # extrai mes/ano e marca feriado se quiser, mas NÃO usamos presion_suavizada
        df = df \
            .withColumn("mes", F.month("fecha")) \
            .withColumn("ano", F.year("fecha")) 

        # remove nulos nas chaves brutas
        df = df.dropna(subset=["cliente","presion","temperatura","volumen"])

        self.data = df
        return self

    def global_anomaly(self):
        # quantis globais exatos em raw
        cols = ["presion","temperatura","volumen"]
        quants = self.data.stat.approxQuantile(cols, [0.1, 0.9], 0.0)
        th = {
            "p10_presion":     quants[0][0], "p90_presion":     quants[0][1],
            "p10_temperatura": quants[1][0], "p90_temperatura": quants[1][1],
            "p10_volumen":     quants[2][0], "p90_volumen":     quants[2][1],
        }

        df = self.data
        df = df \
            .withColumn("anomalia_bin",
                F.when(
                    (col("presion")     < th["p10_presion"])     |
                    (col("presion")     > th["p90_presion"])     |
                    (col("temperatura") < th["p10_temperatura"]) |
                    (col("temperatura") > th["p90_temperatura"]) |
                    (col("volumen")     < th["p10_volumen"])     |
                    (col("volumen")     > th["p90_volumen"])
                , 1).otherwise(0)
            ) \
            .withColumn("anomalia",
                F.when(col("anomalia_bin")==1, "Anomalia").otherwise("Normal")
            )

        self.data = df
        return self

    def train_and_assign_clusters(self):
        # agrupa pelas médias brutas
        summary = self.data.groupBy("cliente") \
            .agg(
                F.mean("presion").alias("presion_med"),
                F.mean("temperatura").alias("temp_med"),
                F.mean("volumen").alias("vol_med")
            )
        pdf = summary.toPandas()
        X = pdf[["presion_med","temp_med","vol_med"]].values

        # treina scaler e KMeans em sklearn
        scaler = StandardScaler()
        Xs     = scaler.fit_transform(X)
        km     = KMeans(n_clusters=NUM_CLUSTERS, random_state=42, n_init=10)
        pdf["cluster"] = km.fit_predict(Xs)

        # persiste artefatos
        os.makedirs("/tmp/models", exist_ok=True)
        joblib.dump(scaler, "/tmp/models/scaler.joblib")
        joblib.dump(km,     "/tmp/models/kmeans_model.joblib")
        s3 = boto3.client("s3")
        s3.upload_file("/tmp/models/scaler.joblib",
                       REFINED_BUCKET, f"{MODEL_PREFIX}/scaler.joblib")
        s3.upload_file("/tmp/models/kmeans_model.joblib",
                       REFINED_BUCKET, f"{MODEL_PREFIX}/kmeans_model.joblib")

        # remete clusters de volta ao Spark
        spark_sum = self.spark.createDataFrame(pdf[["cliente","cluster"]])
        self.data = self.data.join(spark_sum, on="cliente", how="inner")
        return self

    def proxy_anomaly(self):
        # schema de saída, adicionando só anomalia_proxy_cluster
        out_schema = StructType(self.data.schema.fields + [
            StructField("anomalia_proxy_cluster", IntegerType(), False)
        ])

        @pandas_udf(out_schema, PandasUDFType.GROUPED_MAP)
        def flag_proxy(pdf: pd.DataFrame) -> pd.DataFrame:
            # loop EXATAMENTE como no script pandas, sobre as colunas brutas
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
        # grava particionado em Parquet, idêntico ao CSV original
        out = self.data.withColumn(
            "fecha_procesamiento", F.date_format(F.current_timestamp(),"yyyy-MM-dd")
        )
        dyf = DynamicFrame.fromDF(out, self.glue, "refined")
        self.glue.write_dynamic_frame.from_options(
            frame              = dyf,
            connection_type    = "s3",
            connection_options = {
                "path":           f"s3://{REFINED_BUCKET}/dato_refinado",
                "partitionKeys": ["fecha_procesamiento"]
            },
            format             = "parquet"
        )
        return self

def run_pipeline():
    args  = getResolvedOptions(sys.argv, ['JOB_NAME'])
    spark = SparkSession.builder.appName(args['JOB_NAME']).getOrCreate()
    glue  = GlueContext(spark.sparkContext)
    job   = Job(glue)
    job.init(args['JOB_NAME'], args)

    (RefinedPipeline(glue)
        .load_and_enrich()
        .global_anomaly()
        .train_and_assign_clusters()
        .proxy_anomaly()
        .save()
    )

    job.commit()
    logger.info("Pipeline completo executado com sucesso")

if __name__ == "__main__":
    run_pipeline()
