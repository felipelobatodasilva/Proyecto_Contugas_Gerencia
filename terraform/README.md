# Proyecto Contugas - Infraestructura AWS (Terraform)

Esta guía detalla el paso a paso para aprovisionar y ejecutar toda la infraestructura del proyecto Contugas en AWS usando Terraform y scripts bash para los jobs de Glue.

## Estructura del Aprovisionamiento

El orden recomendado de ejecución de los archivos Terraform es:

1. **00-backend.tf** – Configuración del backend remoto de Terraform
2. **01-s3.tf** – Buckets S3 para el Data Lake
3. **02-glue.tf** – Creación de los jobs Glue
4. **03-glue_catalog.tf** – Glue Catalog (bases de datos, tablas, crawlers)
5. **04-athena.tf** – Configuración de Athena

Siga siempre este orden para garantizar el aprovisionamiento correcto y las dependencias entre los recursos.

---

## 1. Aprovisionar solo los Jobs Glue

Comente temporalmente todos los demás archivos `.tf` (como `03-glue_catalog.tf`, `04-athena.tf`, etc.), dejando solo activo el `02-glue.tf` (y los anteriores).

Ejecute:
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

---

## 2. Ejecutar los Jobs Glue Manualmente

> **Atención:** Los jobs Glue deben ejecutarse **uno después del otro, nunca en paralelo**. El segundo job (`contugas_trusted_to_refined`) solo debe iniciarse después de la finalización completa del primer job (`contugas_raw_to_trusted`).
>
> **Importante:** Antes de ejecutar el segundo script `.sh`, confirme en la consola de AWS Glue que el job anterior se completó con éxito (estado `SUCCEEDED`). Solo entonces ejecute el siguiente script.

Utilice los scripts bash creados en la raíz del proyecto para garantizar la ejecución 100% secuencial de los jobs Glue:

### a) Ejecutar el primer job
```bash
bash run_raw_to_trusted.sh
```
Espere el mensaje de éxito antes de continuar.

### b) Ejecutar el segundo job
```bash
bash run_trusted_to_refined.sh
```
Espere el mensaje de éxito antes de continuar.

---

## 3. Aprovisionar el resto de los recursos (Glue Catalog, Crawlers, Athena)

Descomente los archivos `03-glue_catalog.tf` y `04-athena.tf`.

Ejecute nuevamente:
```bash
terraform apply -auto-approve
```

Esto creará:
- Bases de datos y tablas en el Glue Catalog
- Crawlers para catalogar los datos procesados
- Workgroup y configuraciones de Athena

---

## Ejecución y monitoreo de los Crawlers de Glue

Después de crear los jobs de Glue y los recursos necesarios con Terraform (crawlers y athena), ejecute el script para actualizar y catalogar los metadatos de las tablas `trusted` y `refined`:

```bash
chmod +x run_crawlers.sh
./run_crawlers.sh
```

El script iniciará los crawlers `contugas_trusted_crawler` y `contugas_refined_crawler`.

Puede monitorear el progreso de los crawlers desde la Consola de AWS Glue:
- Acceda al servicio Glue en la Consola de AWS
- Haga clic en "Crawlers" en el menú lateral
- Verifique el estado de los crawlers `contugas_trusted_crawler` y `contugas_refined_crawler`

O, si prefiere, utilice el siguiente comando para consultar el estado desde la CLI:

```bash
aws glue get-crawler --name contugas_trusted_crawler
aws glue get-crawler --name contugas_refined_crawler
```

---

## Observaciones Importantes

- **Nunca ejecute los jobs Glue manualmente desde la consola mientras el pipeline esté en ejecución para evitar concurrencia.**
- **Espere siempre la finalización de cada etapa antes de continuar con la siguiente.**
- Si las bases de datos del Glue Catalog ya existen, será necesario eliminarlas manualmente o importarlas a Terraform.
- Los scripts bash utilizan la AWS CLI. Asegúrese de estar autenticado y con los permisos adecuados.

---

## Resumen de Comandos

```bash
# 1. Aprovisionar jobs Glue
cd terraform
terraform init
terraform apply -auto-approve

# 2. Ejecutar jobs Glue manualmente
bash run_raw_to_trusted.sh
bash run_trusted_to_refined.sh

# 3. Descomentar 03-glue_catalog.tf y 04-athena.tf, luego:
terraform apply -auto-approve
```

---

## Flujo Visual

1. **Terraform (02-glue.tf)** → 2. **Job Glue 1 (bash)** → 3. **Job Glue 2 (bash)** → 4. **Terraform (03-glue_catalog.tf, 04-athena.tf)**

---

## Documentación de los archivos Terraform y recursos

A continuación se describe cada archivo `.tf` y los recursos principales definidos en el proyecto, explicando su propósito y función:

### 00-backend.tf
- **Propósito:** Configura el backend remoto de Terraform (por ejemplo, S3 y DynamoDB) para almacenar el estado del proyecto de forma centralizada y segura.
- **Recursos:**
  - `terraform { backend ... }`: Define el backend remoto y sus parámetros.

### 01-s3.tf
- **Propósito:** Crea los buckets S3 que conforman las diferentes capas del Data Lake.
- **Recursos:**
  - `aws_s3_bucket.raw`: Bucket para datos brutos (raw).
  - `aws_s3_bucket.trusted`: Bucket para datos validados (trusted).
  - `aws_s3_bucket.refined`: Bucket para datos procesados (refined).
  - `aws_s3_bucket.scripts`: Bucket para almacenar scripts de Glue.
  - `aws_s3_bucket.athena_results`: Bucket para resultados de consultas Athena.
  - Versionamiento y carpetas iniciales para cada bucket.
- **Archivos subidos a los buckets:**
  - **Contugas_Datos.xlsx** (en el bucket raw): Archivo de datos fuente en formato Excel, utilizado como entrada para el procesamiento.
  - **scripts/glue/raw_to_trusted_01.py** (en el bucket scripts): Script Python de Glue para transformar datos de raw a trusted.
  - **scripts/glue/trusted_to_refined_02.py** (en el bucket scripts): Script Python de Glue para transformar datos de trusted a refined.
  - **Estructura de carpetas vacías** (`data/`, `glue/`, `athena-results/`): Directorios creados para organizar los datos y resultados dentro de cada bucket.

### 02-glue.tf
- **Propósito:** Define los jobs de AWS Glue que procesan los datos en el Data Lake.
- **Recursos:**
  - `aws_iam_role.glue_role`: Rol IAM con permisos para Glue y acceso a los buckets S3.
  - `aws_glue_job.raw_to_trusted`: Job Glue que transforma datos de raw a trusted.
  - `aws_glue_job.trusted_to_refined`: Job Glue que transforma datos de trusted a refined.
  - Scripts y argumentos necesarios para la ejecución de los jobs.

### 03-glue_catalog.tf
- **Propósito:** Configura el Glue Catalog, que permite la catalogación y descubrimiento de los datos procesados.
- **Recursos:**
  - `aws_glue_catalog_database.trusted`: Base de datos Glue para la capa trusted.
  - `aws_glue_catalog_database.refined`: Base de datos Glue para la capa refined.
  - `aws_glue_catalog_table.dados_processados`: Tabla para los datos procesados.
  - `aws_glue_crawler.trusted_crawler`: Crawler para catalogar datos en trusted.
  - `aws_glue_crawler.refined_crawler`: Crawler para catalogar datos en refined.
  - Recursos auxiliares para ejecutar los crawlers en secuencia.

### 04-athena.tf
- **Propósito:** Configura el entorno de Amazon Athena para consultas SQL sobre los datos procesados.
- **Recursos:**
  - `aws_athena_workgroup.contugas`: Workgroup de Athena con configuración de resultados y métricas.
  - Dependencias para asegurar que Athena solo se configure después de la catalogación de datos.

### Scripts Bash
- **run_raw_to_trusted.sh:** Ejecuta el job Glue de raw a trusted y espera su finalización.
- **run_trusted_to_refined.sh:** Ejecuta el job Glue de trusted a refined y espera su finalización.

---

Cada archivo y recurso está diseñado para que el flujo de datos y la infraestructura sigan las mejores prácticas de arquitectura en AWS, garantizando seguridad, trazabilidad y facilidad de operación.

> **Importante:** Para garantizar la orden correcta de ejecución y evitar problemas de concurrencia, mantenga activos solo los archivos `00-backend.tf`, `01-s3.tf` y `02-glue.tf` en las etapas iniciales. Los archivos `03-glue_catalog.tf` y `04-athena.tf` deben ser temporariamente desactivados (puede renomear para `.tf_` o comentar todo el contenido). Solo después de la ejecución manual de los jobs Glue, reactivé esos archivos (vuelva a extender para `.tf` o descomente) y ejecute nuevamente el Terraform.