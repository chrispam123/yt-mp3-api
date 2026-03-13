# outputs.tf
# Valores que Terraform muestra tras ejecutar terraform apply.
# =============================================================================

output "api_gateway_url" {
  description = "URL base de la API Gateway para usar en la app Android"
  value = aws_apigatewayv2_stage.main.invoke_url

}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se guardan los MP3 y estados"
  value       = aws_s3_bucket.main.bucket
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR donde se sube la imagen Docker de Fargate"
  value       = aws_ecr_repository.worker.repository_url
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda coordinadora"
  value       = aws_lambda_function.coordinator.function_name
}

output "cloudwatch_lambda_log_group" {
  description = "Grupo de logs de Lambda en CloudWatch"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_fargate_log_group" {
  description = "Grupo de logs de Fargate en CloudWatch"
  value       = aws_cloudwatch_log_group.fargate.name
}
