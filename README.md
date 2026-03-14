
# yt-mp3-api

Backend API para descarga de vídeos de YouTube y conversión a MP3.
Arquitectura serverless con AWS Lambda, Fargate y S3.

## Requisitos del sistema

    sudo apt update
    sudo apt install git python3 python3-pip python3-venv ffmpeg docker.io awscli -y

Instalar Terraform:

    wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
    unzip terraform_1.5.0_linux_amd64.zip
    sudo mv terraform /usr/local/bin/

## Instalación

    git clone git@github.com:TU_USUARIO/yt-mp3-api.git
    cd yt-mp3-api
    cp .env.example .env
    make install

## Bootstrap AWS (solo la primera vez)

El propietario de la cuenta AWS ejecuta esto una única vez:

    bash scripts/bootstrap-aws.sh

Luego configura tus credenciales:

    aws configure --profile yt_mp3_api_dev

## Infraestructura

    cd infra
    terraform init
    terraform plan
    terraform apply

## Comandos disponibles

    make install          Crea el entorno virtual e instala dependencias
    make update           Actualiza dependencias
    make lint             Ejecuta ruff sobre todo el código
    make build-worker     Construye la imagen Docker del worker
    make deploy           Sube la imagen a ECR
    make package-lambda   Empaqueta Lambda en zip para Terraform
    make run URL=...      Ejecuta el worker localmente
    make clean            Limpia entorno y artefactos

## Flujo de desarrollo

    git checkout develop
    git checkout -b feature/nombre
    # cambios + commits
    git push -u origin feature/nombre
    # Pull Request → develop → release → main → tag vX.Y.Z

## Arquitectura

    App Android
        │ HTTP
        ▼
    API Gateway
        │
        ▼
    Lambda (coordinador)
        ├── escribe estado → S3
        └── lanza tarea   → Fargate
                                │
                                ├── descarga audio (yt-dlp)
                                ├── convierte a MP3 (ffmpeg)
                                └── sube MP3 + estado → S3

    App Android ← pre-signed URL ← Lambda ← polling S3

## Autor
MZK
