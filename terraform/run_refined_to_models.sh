#!/bin/bash

# Executa o job Glue refined_to_models e aguarda sua finalização

set -e

JOB_NAME="contugas_refined_to_models"

# Inicia o job Glue e captura o JobRunId
echo "Iniciando o job Glue: $JOB_NAME"
JOB_RUN_ID=$(aws glue start-job-run --job-name "$JOB_NAME" --query 'JobRunId' --output text)
echo "JobRunId: $JOB_RUN_ID"

echo "Aguardando a finalização do job..."
aws glue wait job-run-succeeded --job-name "$JOB_NAME" --run-id "$JOB_RUN_ID"

echo "Job $JOB_NAME finalizado com sucesso!" 