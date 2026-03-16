# cloudwatch.tf
# Define los grupos de logs para Lambda, Fargate y API Gateway.
# Sin CloudWatch no hay observabilidad, y sin observabilidad no puedes
# saber qué está pasando en tu sistema cuando algo falla en producción.
# =============================================================================

# -----------------------------------------------------------------------------
# LOGS DE LAMBDA
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${var.project_name}-coordinator"

  # Retención de logs 30 días en dev para controlar costes
  # En prod se aumentaría a 90 días o más según requisitos legales
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# -----------------------------------------------------------------------------
# LOGS DE FARGATE
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "fargate" {
  name = "/aws/ecs/${var.project_name}-worker"

  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-fargate-logs"
  }
}

# -----------------------------------------------------------------------------
# LOGS DE API GATEWAY
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/aws/apigateway/${var.project_name}-api"

  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

# -----------------------------------------------------------------------------
# ALARMA DE ERRORES EN LAMBDA
# Notifica cuando Lambda falla más de 3 veces en 5 minutos.
# Es la alarma más importante del sistema porque Lambda es el orquestador.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Lambda ha fallado más de 3 veces en 5 minutos"

  dimensions = {
    FunctionName = aws_lambda_function.coordinator.function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-errors-alarm"
  }
}
