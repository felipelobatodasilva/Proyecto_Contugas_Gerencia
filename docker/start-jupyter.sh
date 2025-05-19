#!/bin/bash

echo "Iniciando Jupyter Notebook com PySpark..."
docker-compose up -d

echo ""
echo "Jupyter Notebook está disponível em: http://localhost:8888"
echo "Os arquivos do projeto estão em: /home/jovyan/work"
echo ""
echo "Para parar o container, execute: docker-compose down" 