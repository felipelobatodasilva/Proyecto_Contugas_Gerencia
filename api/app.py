import streamlit as st
import requests

st.title("Predicción de Modelo - API en tiempo real")

# Formulario para que el usuario ingrese los datos
with st.form("formulario_prediccion"):
    presion = st.number_input("Presión", min_value=0.0, step=0.1)
    temperatura = st.number_input("Temperatura", min_value=0.0, step=0.1)
    volumen = st.number_input("Volumen", min_value=0.0, step=0.1)
    enviar = st.form_submit_button("Predecir")

if enviar:
    url = "http://3.90.233.16:5000/predict"
    payload = {
        "presion": presion,
        "temperatura": temperatura,
        "volumen": volumen
    }
    try:
        # Hacemos POST a la API
        response = requests.post(url, json=payload)
        response.raise_for_status()  # Lanza error si falla la petición

        # Extraemos los datos del JSON de respuesta
        data = response.json()
        prediccion = data.get("prediccion", None)
        cluster = data.get("cluster", None)

        # Mostrar resultado de predicción
        if prediccion is not None:
            if prediccion == 1:
                st.error("🔴 Predicción: Anómalo")
            elif prediccion == 0:
                st.success("🟢 Predicción: Normal")
            else:
                st.warning(f"⚠️ Resultado desconocido: {prediccion}")
        else:
            st.error("No se encontró el campo 'prediccion' en la respuesta.")

        # Mostrar el cluster
        if cluster is not None:
            st.info(f"📊 Pertenencia al cluster: {cluster}")
        else:
            st.warning("⚠️ No se encontró el campo 'cluster' en la respuesta.")

    except requests.exceptions.RequestException as e:
        st.error(f"Error al llamar a la API: {e}")
