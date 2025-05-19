#!/bin/bash
set -e

echo "Iniciando job contugas_trusted_to_refined..."
JOB_RUN_ID=$(aws glue start-job-run --job-name contugas_trusted_to_refined --query 'JobRunId' --output text)
echo "Aguardando o término do job contugas_trusted_to_refined..."
aws glue wait job-run-succeeded --job-name contugas_trusted_to_refined --run-id $JOB_RUN_ID
echo "Job contugas_trusted_to_refined finalizado com sucesso!" 