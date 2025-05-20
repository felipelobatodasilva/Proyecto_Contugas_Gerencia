#!/bin/bash

# Executa os crawlers Glue para atualizar os metadados das tabelas trusted e refined

set -e

TRUSTED_CRAWLER="contugas_trusted_crawler"
REFINED_CRAWLER="contugas_refined_crawler"

# Inicia o crawler trusted
echo "Iniciando o crawler: $TRUSTED_CRAWLER"
aws glue start-crawler --name "$TRUSTED_CRAWLER"

# Inicia o crawler refined
echo "Iniciando o crawler: $REFINED_CRAWLER"
aws glue start-crawler --name "$REFINED_CRAWLER"

echo "Execução dos crawlers iniciada. Use o console AWS ou o comando aws glue get-crawler para monitorar o status." 