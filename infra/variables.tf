# variables.tf
# Define todas las variables parametrizables del proyecto.
# Los valores por defecto corresponden al entorno de desarrollo.
# =============================================================================

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Perfil de AWS CLI a usar para autenticación"
  type        = string
  default     = "yt_mp3_api_dev"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en todos los recursos"
  type        = string
  default     = "yt-mp3-api"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser dev, staging o prod."
  }
}

variable "aws_account_id" {
  description = "ID de la cuenta de AWS"
  type        = string
  default     = "380894354766"
}

variable "fargate_cpu" {
  description = "CPU asignada a la tarea Fargate en unidades de CPU de ECS (256 = 0.25 vCPU)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.fargate_cpu)
    error_message = "Los valores válidos de CPU son 256, 512, 1024, 2048 o 4096."
  }
}

variable "fargate_memory" {
  description = "Memoria asignada a la tarea Fargate en MB"
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 4096], var.fargate_memory)
    error_message = "Los valores válidos de memoria son 512, 1024, 2048 o 4096."
  }
}

variable "rapidapi_key" {
  description = "API key de RapidAPI para ytjar"
  type        = string
  sensitive   = true
  default     = ""

}
