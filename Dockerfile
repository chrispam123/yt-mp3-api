
# =============================================================================
# Dockerfile e
# Empaqueta el worker de Fargate con Python, ffmpeg, yt-dlp
# y todas las dependencias necesarias para procesar audio.
# =============================================================================

# Imagen base oficial de Python 3.11 slim para minimizar el tamaño
FROM python:3.11-slim

# Variables de entorno para evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Instalamos ffmpeg y dependencias del sistema
# Limpiamos la caché de apt en el mismo layer para reducir tamaño de imagen
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        gcc \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copiamos requirements primero para aprovechar la caché de Docker
# Si el código cambia pero requirements.txt no, Docker no reinstala dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos el código fuente
COPY src/shared/ ./src/shared/
COPY src/worker/ ./src/worker/

# Usuario no root por seguridad
# Nunca ejecutar contenedores como root en producción
RUN useradd --create-home appuser
USER appuser

# Punto de entrada del contenedor
# Fargate ejecutará este comando cuando arranque la tarea
CMD ["python", "src/worker/worker.py"]

