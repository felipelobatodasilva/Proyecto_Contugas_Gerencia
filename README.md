# Versionamiento de Datos con DVC y S3

Este proyecto utiliza [DVC (Data Version Control)](https://dvc.org/) para versionar archivos grandes y almacenarlos de manera eficiente en un bucket S3, evitando problemas con el límite de 100MB de GitHub.

## Objetivo
- Versionar archivos grandes (ej: carpetas de datos) sin sobrecargar el repositorio Git.
- Almacenar los datos en un bucket S3 externo.
- Permitir que cualquier colaborador recupere los datos fácilmente.

## Prerrequisitos
- Python 3 instalado
- Git instalado
- Cuenta AWS con acceso a un bucket S3

## Instalación
1. Clone el repositorio:
   ```bash
   git clone https://github.com/felipelobatodasilva/Proyecto_Contugas_Gerencia.git
   cd Proyecto_Contugas_Gerencia
   ```
2. Cree y active un entorno virtual:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Instale DVC con soporte para S3:
   ```bash
   pip install dvc[s3]
   ```

## Configuración de DVC
1. Inicialice DVC en la raíz del proyecto:
   ```bash
   dvc init
   ```
2. Configure el bucket S3 como remoto predeterminado:
   ```bash
   dvc remote add -d contugas-remote s3://contugas-dvc-storage
   ```

## Cómo agregar archivos grandes
1. Agregue la carpeta o archivo grande a DVC (ejemplo con la carpeta `archivo` dentro de `terraform`):
   ```bash
   dvc add terraform/archivo
   ```
2. Agregue los archivos de control a Git:
   ```bash
   git add terraform/archivo.dvc .dvc/config
   git commit -m "Agrega la carpeta archivo a DVC"
   ```

## Cómo enviar los datos a S3
```bash
source venv/bin/activate  # Active el entorno virtual, si es necesario
dvc push
```

## Cómo recuperar los datos en otro entorno
1. Clone el repositorio e instale las dependencias (vea la sección de Instalación)
2. Descargue los datos de S3:
   ```bash
   dvc pull
   ```

## Configuración de las credenciales AWS
Asegúrese de que sus credenciales AWS estén configuradas, por ejemplo, mediante variables de entorno o el archivo `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = SUA_ACCESS_KEY
aws_secret_access_key = SUA_SECRET_KEY
```

### Cómo configurar las credenciales AWS
Si sus credenciales no están configuradas, siga los pasos a continuación:

1. **Instale AWS CLI** (si aún no lo tiene):
   ```bash
   pip install awscli
   ```

2. **Configure sus credenciales**:
   ```bash
   aws configure
   ```
   - Ingrese su AWS Access Key ID
   - Ingrese su AWS Secret Access Key
   - Ingrese la región predeterminada (ej: us-east-1)
   - Ingrese el formato de salida (ej: json)

3. **Verifique la configuración**:
   ```bash
   aws sts get-caller-identity
   ```
   Si todo está correcto, verá información sobre su cuenta AWS.

4. **Alternativa: Configurar mediante variables de entorno**:
   ```bash
   export AWS_ACCESS_KEY_ID=SUA_ACCESS_KEY
   export AWS_SECRET_ACCESS_KEY=SUA_SECRET_KEY
   export AWS_DEFAULT_REGION=us-east-1
   ```

Después de configurar las credenciales, podrá usar DVC para enviar y recuperar datos de S3 sin problemas.

## Comandos útiles
- Agregar nuevo archivo/carpeta a DVC:
  ```bash
  dvc add ruta/del/archivo_o_carpeta
  git add ruta/del/archivo_o_carpeta.dvc
  git commit -m "Agrega ... a DVC"
  dvc push
  ```
- Descargar datos de S3:
  ```bash
  dvc pull
  ``` 