# API de Predicción de Anomalías - Contugas

Este documento explica **paso a paso** cómo preparar el entorno, instalar dependencias, configurar y ejecutar la aplicación FastAPI para predicción de anomalías usando modelos entrenados y almacenados en S3.

---

## 1. Visión General de la Aplicación

Esta API utiliza modelos de machine learning (scaler, kmeans y modelos de cluster) entrenados previamente y guardados en S3 para realizar predicciones de anomalías en datos de sensores (presión, temperatura, volumen). El endpoint principal es `/predict`, que recibe datos vía POST y retorna el cluster y la predicción de anomalía.

- **Tecnologías:** FastAPI, scikit-learn, joblib, boto3, pandas, numpy
- **Modelos:** Guardados en el bucket S3 `contugas-models-dev/models/`
- **Entorno:** Python 3.10 (necesario para compatibilidad con los modelos)

---

## 2. Prerrequisitos

- **Python 3.10** (no funciona con Python 3.12 debido a la compatibilidad de los modelos)
- **Acceso a AWS S3** (credenciales configuradas vía `aws configure` o variables de entorno)
- **Git** (opcional, para clonar el repositorio)

---

## 3. Instalación de Python 3.10 (Ubuntu)

Si no tienes Python 3.10 instalado, ejecuta:

```bash
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y python3.10 python3.10-venv python3.10-distutils
```

---

## 4. Creación del Entorno Virtual

En el directorio `api/`, crea y activa el entorno virtual con Python 3.10:

```bash
python3.10 -m venv venv310
source venv310/bin/activate
```

> **Atención:** Siempre activa el entorno con `source venv310/bin/activate` antes de ejecutar la API.

---

## 5. Instalación de Dependencias

Con el entorno activado, instala las dependencias:

```bash
pip install --upgrade pip
pip install -r requirements.txt
pip install scikit-learn==1.0.2
```

- El archivo `requirements.txt` ya incluye las dependencias principales.
- La versión de `scikit-learn` **debe ser 1.0.2** para garantizar compatibilidad con los modelos guardados.

---

## 6. Configuración de los Modelos

Los modelos necesarios deben estar en el bucket S3 `contugas-models-dev/models/`:
- `scaler.joblib`
- `kmeans_model.joblib`
- `modelo_cluster_0_prod.joblib` hasta `modelo_cluster_4_prod.joblib`

La aplicación descarga automáticamente estos archivos a `/tmp/modelos` al iniciar.

---

## 7. Ejecutando la API

Con el entorno activado y las dependencias instaladas, ejecuta:

```bash
uvicorn main:app --host 0.0.0.0 --port 5000
```

La API estará disponible en `http://localhost:5000` (o en la IP de la máquina, puerto 5000).

Accede a la documentación interactiva en:
```
http://localhost:5000/docs
```

---

## 8. Probando el Endpoint `/predict`

Ejemplo de petición con `curl`:

```bash
curl -X POST "http://localhost:5000/predict" -H "Content-Type: application/json" -d '{"presion": 1.2, "temperatura": 25.5, "volumen": 100.0}'
```

Respuesta esperada:
```json
{"cluster":2,"prediccion":1}
```

---

## 9. Explicación del Funcionamiento de la Aplicación

- **Al iniciar**, la aplicación descarga los modelos de S3 a `/tmp/modelos` (si no existen localmente).
- **El endpoint `/predict`** recibe un JSON con los campos `presion`, `temperatura` y `volumen`.
- Los datos son escalados, el cluster es predicho por el modelo kmeans, y el modelo de anomalía correspondiente al cluster es aplicado.
- La respuesta trae el número del cluster y la predicción de anomalía (`0` o `1`).

---

## 10. Problemas Resueltos

- **Incompatibilidad de versiones:** Los modelos fueron entrenados con scikit-learn 1.0.2, por lo que fue necesario crear un entorno con Python 3.10 e instalar exactamente esa versión de scikit-learn.
- **Bucket correcto:** El código fue ajustado para buscar los modelos en el bucket correcto (`contugas-models-dev`).
- **Puerto ocupado:** Si el puerto 5000 está en uso, detén el proceso antiguo o ejecuta en otro puerto (ej: 5001).

---

## 11. Consejos y Observaciones

- Siempre activa el entorno virtual antes de ejecutar la API.
- Si cambias los modelos, asegúrate de que sean guardados con scikit-learn 1.0.2.
- Para producción, usa un gestor de procesos (ej: systemd, supervisor, docker, etc).
- Para acceder desde fuera de la máquina, libera el puerto 5000 en el firewall/SG.

---

## 12. Implantación en EC2

### 12.1 Transferencia de Archivos a la EC2

Para mover los archivos a la EC2, usamos el comando `scp` desde nuestra máquina local:

```bash
# Desde el directorio del proyecto
scp -i terraform/ssh/manual-ec2-key api/app.py ubuntu@3.90.233.16:/home/ubuntu/api/
scp -i terraform/ssh/manual-ec2-key api/main.py ubuntu@3.90.233.16:/home/ubuntu/api/
```

### 12.2 Configuración en la EC2

1. **Acceder a la EC2**:
```bash
ssh -i terraform/ssh/manual-ec2-key ubuntu@3.90.233.16
```

2. **Activar el ambiente virtual**:
```bash
cd ~/api
source venv/bin/activate
```

3. **Instalar Streamlit**:
```bash
pip install streamlit
```

### 12.3 Ejecución de las Aplicaciones

1. **FastAPI (ya en ejecución en screen)**:
```bash
# Ver screens activos
screen -ls

# Crear nuevo screen para FastAPI (si necesario)
screen -S fastapi
uvicorn main:app --host 0.0.0.0 --port 5000
# Ctrl + A, D para salir del screen
```

2. **Streamlit**:
```bash
# Crear nuevo screen para Streamlit
screen -S streamlit
streamlit run app.py --server.port 8501 --server.address 0.0.0.0
# Ctrl + A, D para salir del screen
```

### 12.4 Acceso a las Aplicaciones

- **FastAPI**: `http://3.90.233.16:5000`
- **Streamlit**: `http://3.90.233.16:8501`

### 12.5 Gestión de Screens

```bash
# Listar screens activos
screen -ls

# Reconectar a un screen
screen -r nombre_screen  # ejemplo: screen -r streamlit

# Salir de un screen (manteniéndolo activo)
# Presionar Ctrl + A, después D

# Terminar un screen
# Dentro del screen: Ctrl + C, después exit
```

### 12.6 Notas Importantes

- Ambos servicios (FastAPI y Streamlit) deben estar ejecutándose simultáneamente
- FastAPI corre en el puerto 5000 y Streamlit en el 8501
- Los puertos 5000 y 8501 deben estar abiertos en el Security Group de la EC2
- El ambiente virtual (venv) debe estar activado antes de ejecutar cualquier servicio