import sys
import io
import logging
import boto3
import joblib
import pandas as pd
import numpy as np

from pyspark.sql import SparkSession
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job

from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import f1_score, precision_score, recall_score

# -------------------- Configuración --------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REFINED_PATH  = "s3://contugas-refined-data-dev/dato_refinado/"
MODELS_BUCKET = "contugas-models-dev"
MODEL_PREFIX  = "models"
NUM_CLUSTERS  = 5
ESTADO_ALEATORIO = 42

# -------------------- Entrenamiento y guardado --------------------
def entrenar_y_guardar_modelos(df, features, n_clusters, s3_client):
    threshold_candidates = np.linspace(-1.0, 1.0, 201)
    resultados = []

    for k in range(n_clusters):
        print(f"\nEntrenando modelo para cluster {k}...")
        df_k = df[df['cluster'] == k].copy()
        if df_k.empty or df_k.shape[0] < 2:
            print(f"Cluster {k} está vacío o tiene pocas muestras. Omitiendo.")
            continue

        X_k = df_k[features]
        y_proxy_k = df_k['anomalia_proxy_cluster']

        if y_proxy_k.nunique() <= 1 or y_proxy_k.sum() == 0:
            print(f"Cluster {k} no tiene suficientes anomalías. Omitiendo.")
            continue

        r = y_proxy_k.mean()
        contamination = np.clip(r, 0.001, 0.499)

        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X_k)

        model = IsolationForest(contamination=contamination, random_state=ESTADO_ALEATORIO)
        model.fit(X_scaled)

        scores = model.decision_function(X_scaled)
        best_f1, best_thr, best_p, best_r = -1, np.nan, 0.0, 0.0
        for thr in threshold_candidates:
            y_pred = (scores < thr).astype(int)
            f1 = f1_score(y_proxy_k, y_pred, zero_division=0)
            if f1 > best_f1:
                best_f1 = f1
                best_thr = thr
                best_p = precision_score(y_proxy_k, y_pred, zero_division=0)
                best_r = recall_score(y_proxy_k, y_pred, zero_division=0)

        paquete_modelo = {
            'model': model,
            'scaler': scaler,
            'features': features,
            'threshold': best_thr
        }

        # Guardar directamente en S3 con BytesIO
        buffer = io.BytesIO()
        joblib.dump(paquete_modelo, buffer)
        buffer.seek(0)
        s3_key = f"{MODEL_PREFIX}/modelo_cluster_{k}_prod.joblib"
        s3_client.upload_fileobj(buffer, MODELS_BUCKET, s3_key)

        resultados.append({
            'Cluster': k,
            'Precision': best_p,
            'Recall': best_r,
            'F1-Score': best_f1,
            'Threshold': best_thr,
            'S3_Key': s3_key
        })

    return pd.DataFrame(resultados).set_index('Cluster')

# -------------------- Pipeline Glue --------------------
def run_pipeline():
    args = getResolvedOptions(sys.argv, ['JOB_NAME'])
    spark = SparkSession.builder.appName(args['JOB_NAME']).getOrCreate()
    glue = GlueContext(spark.sparkContext)
    job = Job(glue)
    job.init(args['JOB_NAME'], args)

    print("Lendo dados refinados do S3...")
    df_spark = spark.read.parquet(REFINED_PATH)
    df = df_spark.select(
        "cliente", "presion", "temperatura", "volumen",
        "cluster", "anomalia_proxy_cluster"
    ).toPandas()

    s3 = boto3.client("s3")
    print("Iniciando treinamento...")
    resultados_df = entrenar_y_guardar_modelos(
        df=df,
        features=['presion', 'temperatura', 'volumen'],
        n_clusters=NUM_CLUSTERS,
        s3_client=s3
    )

    print("Treinamento concluído com sucesso.")
    job.commit()

if __name__ == "__main__":
    run_pipeline()
