from fastapi import FastAPI, Request
import pandas as pd
import joblib
import numpy as np
import os
import boto3
from pydantic import BaseModel

app = FastAPI()

# ------------------ Configuración ------------------
BUCKET_NAME = "contugas-models-dev"
MODELS_PREFIX = "models"
LOCAL_MODELS_PATH = "/tmp/modelos"
os.makedirs(LOCAL_MODELS_PATH, exist_ok=True)

# ------------------ Cliente S3 ------------------
s3 = boto3.client("s3", region_name="us-east-1")

def baixar_modelo_s3(s3_key, local_path):
    if not os.path.exists(local_path):
        print(f"🔽 Baixando {s3_key} do S3...")
        s3.download_file(BUCKET_NAME, s3_key, local_path)
    else:
        print(f"✔️ {s3_key} já existe localmente.")

# ------------------ Descargar scaler y kmeans ------------------
scaler_path = os.path.join(LOCAL_MODELS_PATH, "scaler.joblib")
kmeans_path = os.path.join(LOCAL_MODELS_PATH, "kmeans_model.joblib")

baixar_modelo_s3(f"{MODELS_PREFIX}/scaler.joblib", scaler_path)
baixar_modelo_s3(f"{MODELS_PREFIX}/kmeans_model.joblib", kmeans_path)

scaler = joblib.load(scaler_path)
kmeans = joblib.load(kmeans_path)
n_clusters = kmeans.n_clusters

# ------------------ Descargar modelos por cluster ------------------
modelos_por_cluster = {}
for k in range(n_clusters):
    s3_key = f"{MODELS_PREFIX}/modelo_cluster_{k}_prod.joblib"
    local_path = os.path.join(LOCAL_MODELS_PATH, f"modelo_cluster_{k}_prod.joblib")
    try:
        baixar_modelo_s3(s3_key, local_path)
        modelos_por_cluster[k] = joblib.load(local_path)
    except Exception as e:
        print(f"⚠️ Erro ao carregar modelo del cluster {k}: {e}")

# ------------------ Endpoint ------------------
class InputData(BaseModel):
    presion: float
    temperatura: float
    volumen: float

@app.post("/predict")
async def predict(data: InputData):
    df = pd.DataFrame([data.dict()])
    # Predecir cluster
    X_input = scaler.transform(df[["presion", "temperatura", "volumen"]])
    cluster = int(kmeans.predict(X_input)[0])

    modelo = modelos_por_cluster.get(cluster)
    if not modelo:
        return {"erro": f"Modelo del cluster {cluster} não encontrado"}

    # Aplicar modelo de anomalía
    X_model = modelo["scaler"].transform(df[modelo["features"]])
    score = modelo["model"].decision_function(X_model)[0]
    pred = int(score < modelo["threshold"])

    return {
        "cluster": cluster,
        "prediccion": pred
    } 