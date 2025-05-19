# Ambiente de Validación de Datos Contugas

Este ambiente Docker contiene notebooks Jupyter con PySpark para validación y comparación de procesamiento de datos entre Pandas y PySpark (simulando AWS Glue).

## Estructura del Proyecto

```
docker/
├── Refined/
│   ├── data_cleaned.csv           # Datos procesados y refinados
│   ├── Parquet_Refined_Files/     # Archivos en formato Parquet
│   ├── refined_models/            # Modelos entrenados
│   └── Data_Validacion_Refined.ipynb  # Notebook de validación refinada
├── Trusted/
│   ├── Data_Validation_Trusted.ipynb  # Notebook de validación inicial
│   ├── Contugas_Datos.xlsx        # Datos originales
│   ├── data_cleaned.csv           # Datos limpios
│   └── Parquet_Trusted_Files/     # Archivos en formato Parquet
├── docker-compose.yml             # Configuración del ambiente Docker
├── start-jupyter.sh              # Script para iniciar el ambiente
└── stop-jupyter.sh               # Script para detener el ambiente
```

## Requisitos

- Docker
- Docker Compose
- 4GB de RAM disponible (mínimo)
- 10GB de espacio en disco

## Nota Importante

Este ambiente Docker está diseñado **exclusivamente para ejecución local**. El propósito de este ambiente es:

- Ejecutar localmente las mismas consultas SQL que se procesan en AWS Athena en la nube
- Utilizar PySpark local para procesar los datos de manera idéntica a Athena
- Permitir validación y pruebas de las consultas SQL sin necesidad de acceder a la nube
- Facilitar el desarrollo y depuración de consultas SQL en un ambiente local

Para ejecutar en producción:
- Las mismas consultas SQL se ejecutarán en AWS Athena
- Los datos procesados se almacenarán en S3
- Se mantendrá la consistencia entre los resultados locales y en la nube

## Cómo Ejecutar

1. Navegue hasta la carpeta docker:
```bash
cd docker
```

2. Inicie el ambiente:
```bash
./start-jupyter.sh
```

3. Acceda al Jupyter Lab:
```
http://localhost:8888
```

4. Para detener el ambiente:
```bash
./stop-jupyter.sh
```

## Proceso de Validación

### 1. Validación Inicial (Trusted)

El notebook `Data_Validation_Trusted.ipynb` realiza:

1. **Procesamiento en Pandas**:
   - Carga datos del Excel (`Contugas_Datos.xlsx`)
   - Procesa datos de 20 clientes
   - Realiza limpieza y transformación
   - Genera `data_cleaned.csv`

2. **Validación con PySpark**:
   - Lee el archivo `data_cleaned.csv`
   - Crea vista temporal `contugas_pandas_procedado`
   - Ejecuta consultas de validación:
     - Visualización de las primeras 10 filas
     - Conteo de registros por anomalía
     - Análisis por cliente
     - Verificación de totales
     - Distribución de anomalías

### 2. Validación Refinada (Refined)

El notebook `Data_Validacion_Refined.ipynb` realiza:

1. **Procesamiento Avanzado**:
   - Carga datos limpios
   - Aplica clusterización K-means
   - Genera modelos de detección de anomalías
   - Guarda resultados en formato Parquet

2. **Salidas**:
   - Modelos guardados en `refined_models/`
   - Datos procesados en `Parquet_Refined_Files/`

## Métricas de Validación

### 1. Validación de Datos
- Total de registros: 847,960
- Clientes distintos: 20
- Períodos distintos: 60
- Distribución de anomalías:
  - Normal: 716,210 registros
  - Anómalo: 131,750 registros

### 2. Validación de Procesamiento
- Consistencia entre Pandas y PySpark
- Verificación de integridad de los datos
- Validación de transformaciones
- Prueba de rendimiento

### 3. Equivalencia entre Pandas y PySpark

#### 3.1 Validación de Registros
- **Total de Registros**:
  - Pandas: 847,960 registros
  - PySpark: 847,960 registros
  - ✅ Coincidencia: 100%

#### 3.2 Distribución de Anomalías
- **Pandas**:
  - Normal: 716,210
  - Anómalo: 131,750
- **PySpark**:
  - Normal: 716,210
  - Anómalo: 131,750
- ✅ Coincidencia: 100%

#### 3.3 Distribución por Cliente
- **Ejemplo CLIENTE1**:
  - Anómalo: 8,684 registros
  - Normal: 34,728 registros
- ✅ Coincidencia: 100% para todos los clientes

#### 3.4 Consistencia de Datos
- Mismo número de clientes distintos (20)
- Mismo número de períodos distintos (60)
- Mismos valores para todas las métricas
- ✅ Coincidencia: 100%

#### 3.5 Valores Binarios
- Anomalia_bin 0: 716,210 registros
- Anomalia_bin 1: 131,750 registros
- ✅ Coincidencia: 100%

#### 3.6 Consistencia entre Columnas
- Anomalia "Normal" siempre corresponde a Anomalia_bin 0
- Anomalia "Anómalo" siempre corresponde a Anomalia_bin 1
- ✅ Coincidencia: 100%

## Revalidación

Para revalidar los datos:

1. Inicie el ambiente Docker
2. Abra el notebook `Data_Validation_Trusted.ipynb`
3. Ejecute todas las celdas en secuencia
4. Verifique las métricas de validación
5. Compare con los resultados anteriores

## Configuración del Ambiente

El `docker-compose.yml` configura:
- Imagen: jupyter/pyspark-notebook
- Puerto: 8888
- Memoria Spark: 1GB min, 4GB max
- Volúmenes montados para persistencia de datos

## Solución de Problemas

1. **Error de Memoria**:
   - Aumente la memoria del driver en el `docker-compose.yml`
   - Reduzca el tamaño de los lotes de procesamiento

2. **Error de Conexión**:
   - Verifique si el puerto 8888 está disponible
   - Reinicie el contenedor

3. **Error de Datos**:
   - Verifique los logs del contenedor
   - Confirme la integridad de los archivos de entrada

## Contribución

Para contribuir con el proyecto:
1. Haga fork del repositorio
2. Cree una rama para su feature
3. Commit sus cambios
4. Push a la rama
5. Cree un Pull Request