# =============================================================================
# lambda.tf
# Define la función Lambda coordinadora y su rol IAM con mínimos privilegios.
# Lambda es el orquestador: recibe peticiones de API Gateway, gestiona
# el estado en S3, y lanza tareas de Fargate para el procesamiento pesado.
# =============================================================================

# -----------------------------------------------------------------------------
# ROL IAM DE LAMBDA
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  # Política de confianza: solo Lambda puede asumir este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}


# Política de permisos mínimos para Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/tasks/*"
        ]
      },
      {
        Sid    = "ECSAccess"
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        # Restringido únicamente a la definición de tarea de Fargate
        Resource = "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${var.project_name}-*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        # Solo puede pasar el rol de Fargate, no cualquier rol
        Resource = aws_iam_role.fargate_role.arn
      },

      {
        Sid      = "PassRole",
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = [
          aws_iam_role.fargate_role.arn,
          # Si tienes un rol de ejecución separado (Task Execution Role), añádelo aquí también:
          # aws_iam_role.ecs_task_execution_role.arn
        ]
      },

      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# FUNCIÓN LAMBDA
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "coordinator" {
  function_name = "${var.project_name}-coordinator"
  role          = aws_iam_role.lambda_role.arn

  # El código se desplegará desde un archivo zip
  # Por ahora usamos un placeholder hasta que el código esté listo
filename         = "../build/lambda_placeholder.zip"
source_code_hash = filebase64sha256("../build/lambda_placeholder.zip")

  handler       = "src.lambda.handler.lambda_handler"
  runtime       = "python3.11"

  # Tiempo máximo de ejecución en segundos
  # Lambda solo coordina, no procesa audio, 30 segundos es más que suficiente
  timeout = 30

  # Memoria asignada a la función
  # 128 MB es suficiente para una función coordinadora ligera
  memory_size = 128

  # Variables de entorno que el código Python leerá con os.getenv()
  environment {
    variables = {
      PROJECT_NAME    = var.project_name
      ENVIRONMENT     = var.environment
      S3_BUCKET       = aws_s3_bucket.main.bucket
      ECS_CLUSTER     = aws_ecs_cluster.main.name
      TASK_DEFINITION = "${var.project_name}-worker"
       REGION_NAME =        var.aws_region
      SUBNET_ID         = aws_subnet.public.id
      SECURITY_GROUP_ID = aws_security_group.fargate.id
    }
  }

  tags = {
    Name = "${var.project_name}-coordinator"
  }
}

# Permiso para que API Gateway pueda invocar la función Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.coordinator.function_name
  principal     = "apigateway.amazonaws.com"
}
