
"""
downloader.py
Responsabilidad: descargar el stream de audio desde una URL de YouTube.
Módulo compartido entre Lambda y Fargate.
"""

import yt_dlp
from pathlib import Path


def build_ydl_options(output_dir: Path, audio_quality: int) -> dict:
    return {
        "format": "bestaudio/best",
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": str(audio_quality),
        }],
        "outtmpl": str(output_dir / "%(title)s.%(ext)s"),
        "quiet": True,
        "no_warnings": True,
    }


def download_audio(url: str, output_dir: Path, audio_quality: int = 2) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    options = build_ydl_options(output_dir, audio_quality)

    try:
        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(url, download=True)
            return {
                "title": info.get("title", "Desconocido"),
                "duration": info.get("duration", 0),
                "uploader": info.get("uploader", "Desconocido"),
                "filename": f"{info.get('title', 'audio')}.mp3"
            }
    except yt_dlp.utils.DownloadError as e:
        raise RuntimeError(f"Error al descargar el vídeo: {e}") from e

