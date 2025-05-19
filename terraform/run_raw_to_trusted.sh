#!/bin/bash
set -e

echo "Iniciando job contugas_raw_to_trusted..."
JOB_RUN_ID=$(aws glue start-job-run --job-name contugas_raw_to_trusted --query 'JobRunId' --output text)
echo "Aguardando o término do job contugas_raw_to_trusted..."
aws glue wait job-run-succeeded --job-name contugas_raw_to_trusted --run-id $JOB_RUN_ID
echo "Job contugas_raw_to_trusted finalizado com sucesso!" 