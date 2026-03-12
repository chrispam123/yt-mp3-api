
"""
worker.py
Responsabilidad: worker de Fargate.
Recibe la URL y task_id como variables de entorno,
descarga el audio, convierte a MP3, sube a S3 y actualiza el estado.
"""

import json
import os
import sys
import boto3
from pathlib import Path
from datetime import datetime

# Añadimos src/shared al path para importar los módulos compartidos
sys.path.append(str(Path(__file__).parent.parent / "shared"))

from downloader import download_audio
from converter import check_ffmpeg

# Variables de entorno que Lambda pasa a Fargate al lanzar la tarea
TASK_ID    = os.getenv("TASK_ID")
URL        = os.getenv("URL")
S3_BUCKET  = os.getenv("S3_BUCKET")
AWS_REGION = os.getenv("AWS_REGION")

s3_client = boto3.client("s3", region_name=AWS_REGION)
TMP_DIR   = Path("/tmp/downloads")


def update_status(task_id: str, status: str, extra: dict = {}) -> None:
    """Actualiza el estado de la tarea en S3."""

    # Borramos el estado anterior antes de escribir el nuevo
    prefix = f"tasks/{task_id}/"
    result = s3_client.list_objects_v2(Bucket=S3_BUCKET, Prefix=prefix)

    if "Contents" in result:
        for obj in result["Contents"]:
            if "status=" in obj["Key"]:
                s3_client.delete_object(Bucket=S3_BUCKET, Key=obj["Key"])

    # Escribimos el nuevo estado
    status_key = f"tasks/{task_id}/status={status}"
    payload = {
        "task_id":    task_id,
        "status":     status,
        "updated_at": datetime.utcnow().isoformat(),
        **extra
    }
    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=status_key,
        Body=json.dumps(payload).encode("utf-8")
    )


def upload_mp3(task_id: str, mp3_path: Path) -> str:
    """Sube el archivo MP3 a S3 y devuelve la key del objeto."""
    s3_key = f"tasks/{task_id}/audio.mp3"
    s3_client.upload_file(
        Filename=str(mp3_path),
        Bucket=S3_BUCKET,
        Key=s3_key
    )
    return s3_key


def main() -> None:
    """Flujo principal del worker."""

    # Validación de variables de entorno obligatorias
    if not TASK_ID or not URL or not S3_BUCKET:
        print("✗ Variables de entorno TASK_ID, URL y S3_BUCKET son obligatorias")
        sys.exit(1)

    print(f"→ Iniciando tarea {TASK_ID}")
    print(f"→ URL: {URL}")

    try:
        # Paso 1: verificar ffmpeg
        check_ffmpeg()
        print("✓ ffmpeg disponible")

        # Paso 2: descargar y convertir audio
        print("→ Descargando audio...")
        info = download_audio(
            url=URL,
            output_dir=TMP_DIR,
            audio_quality=2
        )
        print(f"✓ Audio descargado: {info['title']}")

        # Paso 3: encontrar el archivo MP3 generado
        mp3_files = list(TMP_DIR.glob("*.mp3"))
        if not mp3_files:
            raise FileNotFoundError("No se generó ningún archivo MP3")
        mp3_path = mp3_files[0]

        # Paso 4: subir MP3 a S3
        print("→ Subiendo MP3 a S3...")
        s3_key = upload_mp3(TASK_ID, mp3_path)
        print(f"✓ MP3 subido: {s3_key}")

        # Paso 5: actualizar estado a completed
        update_status(TASK_ID, "completed", {
            "title":    info["title"],
            "duration": info["duration"],
            "uploader": info["uploader"],
            "s3_key":   s3_key
        })
        print(f"✓ Tarea {TASK_ID} completada")

    except Exception as e:
        print(f"✗ Error en tarea {TASK_ID}: {e}")
        update_status(TASK_ID, "error", {"error": str(e)})
        sys.exit(1)


if __name__ == "__main__":
    main()

