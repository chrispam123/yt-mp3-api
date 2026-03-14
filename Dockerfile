
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
WORKDIR /app/

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

# Creamos el usuario sin privilegios
RUN useradd --create-home appuser

# Copiamos el código fuente asignando la propiedad al appuser desde el inicio
COPY --chown=appuser:appuser src/ ./src/

# Garantizamos que el appuser sea dueño del directorio de trabajo
RUN chown -R appuser:appuser /app/

# Cambiamos al usuario no root de forma segura
USER appuser

ENV PYTHONPATH="/app/src"
CMD ["python", "src/worker/worker.py"]

