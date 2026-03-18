# fargate.tf
# Define el repositorio ECR, el cluster ECS, la definición de tarea
# de Fargate y su rol IAM con mínimos privilegios.
# Fargate es el worker pesado: descarga el audio, convierte a MP3
# y sube el resultado a S3.
# =============================================================================

# -----------------------------------------------------------------------------
# ECR — Repositorio de imágenes Docker
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "worker" {
  name                 = "${var.project_name}-worker"
  image_tag_mutability = "MUTABLE"

  # Escaneo automático de vulnerabilidades en cada imagen subida
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-worker"
  }
}

# Política de ciclo de vida del repositorio ECR
# Mantiene solo las últimas 5 imágenes para controlar el coste de almacenamiento
resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener solo las últimas 5 imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ROL IAM DE FARGATE
# -----------------------------------------------------------------------------

resource "aws_iam_role" "fargate_role" {
  name = "${var.project_name}-fargate-role"

  # Política de confianza: solo ECS Tasks pueden asumir este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-fargate-role"
  }
}

# Política de permisos mínimos para Fargate
resource "aws_iam_role_policy" "fargate_policy" {
  name = "${var.project_name}-fargate-policy"
  role = aws_iam_role.fargate_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/tasks/*",
          "${aws_s3_bucket.main.arn}/config/*"

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
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/${var.project_name}-*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS CLUSTER
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  # Activar Container Insights para monitorización avanzada en CloudWatch
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# -----------------------------------------------------------------------------
# DEFINICIÓN DE TAREA FARGATE
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.fargate_role.arn
  task_role_arn            = aws_iam_role.fargate_role.arn

  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-worker"
      image = "${aws_ecr_repository.worker.repository_url}:latest"

      # Variables de entorno que worker.py leerá con os.getenv()
      environment = [
        {
          name  = "S3_BUCKET"
          value = aws_s3_bucket.main.bucket
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },

        {
          name  = "RAPIDAPI_KEY"
          value = var.rapidapi_key
        },

        {
          name  = "RAPIDAPI_HOST"
          value = "youtube-mp36.p.rapidapi.com"
        },

        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      # Configuración de logs hacia CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/${var.project_name}-worker"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-worker"
  }
}
