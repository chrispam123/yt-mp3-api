"""
downloader.py
Responsabilidad: descargar el stream de audio usando ytjar API.
Módulo compartido entre Lambda y Fargate.
"""

import os
import time
from pathlib import Path

import requests

RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")
RAPIDAPI_HOST = "youtube-mp36.p.rapidapi.com"
YTJAR_URL = f"https://{RAPIDAPI_HOST}/dl"
MAX_RETRIES = 60  # máximo 60 reintentos x 1s = 60 segundos esperando


def extract_video_id(url: str) -> str:
    """Extrae el ID del vídeo de una URL de YouTube."""
    if "youtu.be/" in url:
        return url.split("youtu.be/")[-1].split("?")[0]
    if "v=" in url:
        return url.split("v=")[-1].split("&")[0]
    raise ValueError(f"No se pudo extraer el ID del vídeo de: {url}")


def download_audio(url: str, output_dir: Path, audio_quality: int = 2) -> dict:
    """
    Descarga el audio de YouTube usando ytjar API.
    Hace polling hasta que el estado sea 'ok' o 'fail'.
    Devuelve un dict con título, duración y nombre de archivo.
    """
    if not RAPIDAPI_KEY:
        raise EnvironmentError("Variable de entorno RAPIDAPI_KEY no está configurada")

    output_dir.mkdir(parents=True, exist_ok=True)
    video_id = extract_video_id(url)

    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPI_HOST,
    }

    print(f"→ Solicitando conversión a ytjar para ID: {video_id}")

    for attempt in range(1, MAX_RETRIES + 1):
        response = requests.get(
            YTJAR_URL,
            headers=headers,
            params={"id": video_id},
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        status = data.get("status")

        if status == "ok":
            mp3_url = data.get("link")
            title = data.get("title", "audio")
            print(f"✓ Conversión completada: {title}")

            # Descargamos el MP3 desde el link temporal de ytjar
            print("→ Descargando MP3 desde ytjar...")
            safe_title = "".join(c for c in title if c.isalnum() or c in " -_")[:100]
            mp3_path = output_dir / f"{safe_title}.mp3"

            mp3_response = requests.get(mp3_url, timeout=120, stream=True)
            mp3_response.raise_for_status()

            with open(mp3_path, "wb") as f:
                for chunk in mp3_response.iter_content(chunk_size=8192):
                    f.write(chunk)

            print(f"✓ MP3 descargado: {mp3_path.name}")

            return {
                "title": title,
                "duration": 0,
                "uploader": "YouTube",
                "filename": mp3_path.name,
            }

        elif status == "processing":
            print(f"→ Procesando en ytjar, intento {attempt}/{MAX_RETRIES}...")
            time.sleep(1)

        elif status == "fail":
            msg = data.get("msg", "Error desconocido en ytjar")
            raise RuntimeError(f"ytjar falló: {msg}")

        else:
            raise RuntimeError(f"Estado inesperado de ytjar: {status}")

    raise RuntimeError(f"ytjar no completó la conversión después de {MAX_RETRIES} intentos")
