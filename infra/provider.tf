# provider.tf
# Configura el provider de AWS y el backend remoto donde Terraform
# guardará su estado. Este archivo es el primero que lee Terraform
# y establece el contexto global de toda la infraestructura.
# =============================================================================
#forzar el git
terraform {
  # Versión mínima de Terraform requerida
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto: el estado de Terraform se guarda en S3
  # Este bucket fue creado manualmente en el paso de bootstrap
  # porque Terraform no puede crear su propio backend
  backend "s3" {
    bucket = "yt-mp3-api-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "eu-west-1"

  }
}

# Configuración del provider de AWS
provider "aws" {
  region = var.aws_region


  # Etiquetas por defecto que se aplicarán a todos los recursos
  # que Terraform cree. Esto es una buena práctica porque permite
  # identificar en la consola de AWS a qué proyecto y entorno
  # pertenece cada recurso sin tener que recordarlo.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
