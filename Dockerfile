FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app/src

WORKDIR /app

# Instalamos solo wget para descargar ffmpeg estático
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Descargamos ffmpeg como binario estático (~80MB vs ~600MB de apt)
RUN wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz && \
    tar xf ffmpeg-release-amd64-static.tar.xz && \
    mv ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/ && \
    mv ffmpeg-*-amd64-static/ffprobe /usr/local/bin/ && \
    rm -rf ffmpeg-* && \
    apt-get purge -y wget xz-utils && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip cache purge && \
    find /usr/local/lib/python3.11 -name "*.pyc" -delete && \
    find /usr/local/lib/python3.11 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

COPY --chown=appuser:appuser src/ ./src/

RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app
USER appuser

CMD ["python", "src/worker/worker.py"]
