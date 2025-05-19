# Workgroup para consultas Athena
resource "aws_athena_workgroup" "contugas" {
  depends_on = [null_resource.run_crawlers]
  name = "contugas_workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/athena-results/"
    }
  }
}

# Recurso para verificar o status dos crawlers antes de criar o workgroup
resource "null_resource" "wait_for_crawlers" {
  depends_on = [null_resource.run_crawlers]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verificando status dos crawlers..."
      
      echo "Verificando crawler trusted..."
      for i in {1..12}; do
        STATUS=$(aws glue get-crawler --name contugas_trusted_crawler --query 'Crawler.State' --output text)
        if [ "$STATUS" = "READY" ]; then
          echo "Crawler trusted está pronto!"
          break
        fi
        echo "Status atual do crawler trusted: $STATUS. Aguardando 10 segundos..."
        sleep 10
      done
      
      echo "Verificando crawler refined..."
      for i in {1..12}; do
        STATUS=$(aws glue get-crawler --name contugas_refined_crawler --query 'Crawler.State' --output text)
        if [ "$STATUS" = "READY" ]; then
          echo "Crawler refined está pronto!"
          break
        fi
        echo "Status atual do crawler refined: $STATUS. Aguardando 10 segundos..."
        sleep 10
      done
    EOT
  }
} 