import sys
import os
import logging
import boto3
import joblib
import pandas as pd

from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import IntegerType
from pyspark.sql.functions import udf
from awsglue.context     import GlueContext
from awsglue.job         import Job
from awsglue.utils       import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame

from sklearn.preprocessing import StandardScaler
from sklearn.cluster       import KMeans

# ─── Configuración ─────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TRUSTED_BUCKET = "contugas-trusted-data-dev"
REFINED_BUCKET = "contugas-refined-data-dev"
NUM_CLUSTERS   = 5
MODEL_PREFIX   = "models"  # carpeta en S3 para scaler.joblib y kmeans_model.joblib

class RefinedPipeline:
    def __init__(self, glue_context):
        self.glue_context = glue_context
        self.spark        = glue_context.spark_session
        self.data         = None

    def load_latest_data(self):
        dyf = self.glue_context.create_dynamic_frame.from_options(
            "s3",
            {"paths": [f"s3://{TRUSTED_BUCKET}/dato_procesado"]},
            "parquet"
        )
        df = dyf.toDF() \
            .withColumn("presion",     F.col("presion").cast("double")) \
            .withColumn("temperatura", F.col("temperatura").cast("double")) \
            .withColumn("volumen",     F.col("volumen").cast("double"))
        df = df.dropna(subset=["cliente", "presion", "temperatura", "volumen"])
        logger.info(f"Dados carregados: {df.count()} registros válidos")
        self.data = df
        return self

    def create_and_persist_sklearn_models(self):
        # 1) Agrupa no Spark e pasa para pandas
        summary = (
            self.data
                .groupBy("cliente")
                .agg(
                    F.mean("presion").alias("presion_media"),
                    F.mean("temperatura").alias("temperatura_media"),
                    F.mean("volumen").alias("volumen_media")
                )
        )
        summary_pd = summary.toPandas()

        # 2) Treina scaler e KMeans en sklearn
        feats = summary_pd[["presion_media","temperatura_media","volumen_media"]].values
        scaler = StandardScaler()
        feats_scaled = scaler.fit_transform(feats)
        kmeans = KMeans(
            n_clusters   = NUM_CLUSTERS,
            random_state = 42,
            n_init       = 10,
            init         = "k-means++"
        )
        labels = kmeans.fit_predict(feats_scaled)
        summary_pd["cluster"] = labels
        logger.info("Sklearn: scaler e KMeans treinados com sucesso")

        # 3) Salva modelos em /tmp e envia para S3
        os.makedirs("/tmp/models", exist_ok=True)
        joblib.dump(scaler, "/tmp/models/scaler.joblib")
        joblib.dump(kmeans, "/tmp/models/kmeans_model.joblib")
        s3 = boto3.client("s3")
        s3.upload_file("/tmp/models/scaler.joblib",
                       REFINED_BUCKET,
                       f"{MODEL_PREFIX}/scaler.joblib")
        s3.upload_file("/tmp/models/kmeans_model.joblib",
                       REFINED_BUCKET,
                       f"{MODEL_PREFIX}/kmeans_model.joblib")
        logger.info(f"Modelos salvos em s3://{REFINED_BUCKET}/{MODEL_PREFIX}/")

        # 4) Volta para Spark e faz join dos clusters
        spark_summary = self.spark.createDataFrame(
            summary_pd[["cliente","cluster"]]
        )
        self.data = self.data.join(spark_summary, on="cliente", how="inner")
        logger.info(f"Clusters atribuídos (total: {self.data.count()})")
        return self

    def calculate_anomaly_proxies(self):
        # 1) calcula P10/P90 por cluster
        cluster_stats = (
            self.data
                .groupBy("cluster")
                .agg(
                    F.expr("percentile_approx(presion,   0.1, 10000)").alias("p10_presion"),
                    F.expr("percentile_approx(presion,   0.9, 10000)").alias("p90_presion"),
                    F.expr("percentile_approx(temperatura,0.1,10000)").alias("p10_temperatura"),
                    F.expr("percentile_approx(temperatura,0.9,10000)").alias("p90_temperatura"),
                    F.expr("percentile_approx(volumen,    0.1,10000)").alias("p10_volumen"),
                    F.expr("percentile_approx(volumen,    0.9,10000)").alias("p90_volumen")
                )
        )

        # 2) faz join das estatísticas com a base original
        df = self.data.join(cluster_stats, on="cluster", how="inner")

        # 3) marca anomalias por feature
        df = (
            df
                .withColumn("anomalia_presion",
                            F.when((F.col("presion") < F.col("p10_presion")) |
                                   (F.col("presion") > F.col("p90_presion")), 1).otherwise(0))
                .withColumn("anomalia_temperatura",
                            F.when((F.col("temperatura") < F.col("p10_temperatura")) |
                                   (F.col("temperatura") > F.col("p90_temperatura")), 1).otherwise(0))
                .withColumn("anomalia_volumen",
                            F.when((F.col("volumen") < F.col("p10_volumen")) |
                                   (F.col("volumen") > F.col("p90_volumen")), 1).otherwise(0))
        )

        # 4) cria coluna única de anomalia proxy
        df = df.withColumn(
            "Anomalia_Proxy_Cluster",
            F.greatest("anomalia_presion",
                       "anomalia_temperatura",
                       "anomalia_volumen")
        )

        # 5) remove colunas auxiliares
        drops = [
            "p10_presion","p90_presion",
            "p10_temperatura","p90_temperatura",
            "p10_volumen","p90_volumen",
            "anomalia_presion","anomalia_temperatura","anomalia_volumen"
        ]
        self.data = df.drop(*drops)
        logger.info("Proxies de anomalia calculados com sucesso")
        return self

    def save_refined_data(self):
        # gera coluna de data e grava particionado
        self.data = self.data.withColumn(
            "fecha_procesamiento",
            F.date_format(F.current_timestamp(), "yyyy-MM-dd")
        )
        dyf = DynamicFrame.fromDF(self.data, self.glue_context, "refined")
        self.glue_context.write_dynamic_frame.from_options(
            frame              = dyf,
            connection_type    = "s3",
            connection_options = {
                "path":           f"s3://{REFINED_BUCKET}/dato_refinado",
                "partitionKeys": ["fecha_procesamiento"]
            },
            format             = "parquet"
        )
        logger.info("Datos refinados guardados en Parquet particionado por fecha_procesamiento")
        return self

def run_pipeline():
    args       = getResolvedOptions(sys.argv, ['JOB_NAME'])
    spark      = SparkSession.builder.appName(args['JOB_NAME']).getOrCreate()
    glueContext= GlueContext(spark.sparkContext)
    job        = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    (RefinedPipeline(glueContext)
        .load_latest_data()
        .create_and_persist_sklearn_models()
        .calculate_anomaly_proxies()
        .save_refined_data()
    )

    job.commit()
    logger.info("Pipeline Glue finalizado con éxito")

if __name__ == "__main__":
    run_pipeline()
