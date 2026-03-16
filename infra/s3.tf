# =============================================================================
# s3.tf
# Define el bucket S3 de la aplicación con dos responsabilidades:
# 1. Almacenar los archivos de estado de las tareas (processing/completed/error)
# 2. Almacenar los archivos MP3 generados por Fargate
# =============================================================================

resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-bucket"

  tags = {
    Name = "${var.project_name}-${var.environment}-bucket"
  }
}

# Bloquear todo acceso público al bucket
# Nunca debe ser accesible públicamente, solo mediante pre-signed URLs
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configuración del ciclo de vida para limpieza automática
# Los archivos de estado y MP3 se borran automáticamente después de 24 horas
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "cleanup-tasks"
    status = "Enabled"

    # Aplica a todos los archivos dentro de la carpeta tasks/
    filter {
      prefix = "tasks/"
    }

    # Borra los archivos después de 1 día automáticamente
    expiration {
      days = 1
    }
  }
}

# Política del bucket que restringe el acceso únicamente
# a los roles IAM de Lambda y Fargate
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",

          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },
      {
        Sid    = "AllowFargateAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.fargate_role.arn
        }
        Action = [
          "s3:PutObject",

        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}
