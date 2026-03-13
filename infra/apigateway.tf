# apigateway.tf
# Define la API Gateway HTTP que actúa como puerta de entrada al sistema.
# Recibe las peticiones de la app Android y las enruta hacia Lambda.
# =============================================================================

# -----------------------------------------------------------------------------
# API HTTP
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway para ${var.project_name} — enruta peticiones hacia Lambda"

  # CORS: permite que la app Android haga peticiones a esta API
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["Content-Type"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# -----------------------------------------------------------------------------
# POLÍTICA DE RECURSOS DE CLOUDWATCH (Nativo para HTTP APIs v2)
# -----------------------------------------------------------------------------
# Reemplaza al antiguo Rol de IAM. Permite a API Gateway escribir logs directamente.
resource "aws_cloudwatch_log_resource_policy" "apigw" {
  policy_name = "${var.project_name}-apigw-logging-policy"
  
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*" 
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# STAGE DE DESPLIEGUE
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  # Obligamos a Terraform a esperar a que la política nativa y el log group existan
  depends_on = [
    aws_cloudwatch_log_resource_policy.apigw,
    aws_cloudwatch_log_group.api_gateway
  ]

  # Logs de acceso hacia CloudWatch (Limpiamos el ARN por si acaso)
  access_log_settings {
    destination_arn = replace(aws_cloudwatch_log_group.api_gateway.arn, ":*", "")
    format          = "$context.requestId $context.httpMethod $context.path $context.status"
  }

  tags = {
    Name = "${var.project_name}-stage-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# INTEGRACIÓN CON LAMBDA
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.coordinator.invoke_arn
  integration_method = "POST"

  # AWS_PROXY significa que API Gateway pasa la petición completa
  # a Lambda sin modificarla, y Lambda devuelve la respuesta completa.
  # Lambda es responsable de parsear la petición y construir la respuesta.
  payload_format_version = "2.0"
}

# -----------------------------------------------------------------------------
# RUTAS
# -----------------------------------------------------------------------------

# POST /download — recibe la URL de YouTube e inicia la descarga
resource "aws_apigatewayv2_route" "download" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /download"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# GET /status/{id} — consulta el estado de una tarea específica
resource "aws_apigatewayv2_route" "status" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /status/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}
