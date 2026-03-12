
# =============================================================================
# network.tf
# Define la VPC, subnet pública y security group para Fargate.
# Fargate necesita acceso a internet para descargar audio de YouTube
# y comunicarse con S3 y ECR.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# Permite que la subnet pública tenga acceso a internet
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -----------------------------------------------------------------------------
# SUBNET PÚBLICA
# Fargate se ejecuta aquí con IP pública para acceder a internet
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public"
  }
}

# -----------------------------------------------------------------------------
# TABLA DE RUTAS
# Dirige el tráfico de la subnet pública hacia internet
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# SECURITY GROUP
# Sin reglas de entrada (ingress): nadie puede conectarse a Fargate.
# Solo salida a internet para descargar audio y comunicarse con AWS.
# -----------------------------------------------------------------------------

resource "aws_security_group" "fargate" {
  name        = "${var.project_name}-fargate-sg"
  description = "Security group para Fargate worker. Sin ingress por seguridad."
  vpc_id      = aws_vpc.main.id

  # Sin reglas de entrada — nadie puede conectarse al contenedor
  # Fargate no necesita recibir conexiones de ningún tipo

  # Salida libre a internet para:
  # - Descargar audio de YouTube via yt-dlp
  # - Subir MP3 a S3
  # - Descargar imagen Docker desde ECR
  # - Escribir logs en CloudWatch
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Salida libre a internet"
  }

  tags = {
    Name = "${var.project_name}-fargate-sg"
  }
}

