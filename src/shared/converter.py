"""
converter.py
Responsabilidad: verificar dependencias del sistema y utilidades de audio.
Módulo compartido entre Lambda y Fargate.
"""

import shutil


def check_ffmpeg() -> None:
    if shutil.which("ffmpeg") is None:
        raise EnvironmentError(
            "ffmpeg no está instalado o no está en el PATH del sistema.\n"
            "En Ubuntu/Debian: sudo apt install ffmpeg -y"
        )


def format_duration(seconds: int) -> str:
    minutes, secs = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"
