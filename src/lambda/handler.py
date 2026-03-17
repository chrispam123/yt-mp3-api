"""
handler.py
Responsabilidad: coordinador Lambda.
Recibe peticiones de API Gateway, gestiona estados en S3,
y lanza tareas de Fargate para el procesamiento pesado.
"""

import json
import os
import uuid
from datetime import datetime

import boto3

# Clientes AWS inicializados fuera del handler para reutilizarlos
# entre invocaciones en el mismo contenedor Lambda (warm start)
s3_client = boto3.client("s3")
ecs_client = boto3.client("ecs")

# Variables de entorno definidas en lambda.tf
S3_BUCKET = os.getenv("S3_BUCKET")
ECS_CLUSTER = os.getenv("ECS_CLUSTER")
TASK_DEFINITION = os.getenv("TASK_DEFINITION")
AWS_REGION = os.getenv("REGION_NAME")


def response(status_code: int, body: dict) -> dict:
    """Construye la respuesta HTTP que API Gateway devolverá al cliente."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def create_task(url: str) -> dict:
    task_id = str(uuid.uuid4())
    status_key = f"tasks/{task_id}/status=processing"

    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=status_key,
        Body=json.dumps(
            {
                "task_id": task_id,
                "url": url,
                "status": "processing",
                "created_at": datetime.utcnow().isoformat(),
            }
        ).encode("utf-8"),
    )

    try:
        container_name = f"{os.getenv('PROJECT_NAME')}-worker"

        print(
            f"DEBUG: Intentando lanzar tarea en cluster '{ECS_CLUSTER}'"
            f"con contenedor '{container_name}'"
        )

        response_ecs = ecs_client.run_task(
            cluster=ECS_CLUSTER,
            taskDefinition=TASK_DEFINITION,
            launchType="FARGATE",
            overrides={
                "containerOverrides": [
                    {
                        "name": container_name,
                        "environment": [
                            {"name": "TASK_ID", "value": task_id},
                            {"name": "URL", "value": url},
                        ],
                    }
                ]
            },
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": [os.getenv("SUBNET_ID")],
                    "securityGroups": [os.getenv("SECURITY_GROUP_ID")],
                    "assignPublicIp": "ENABLED",
                }
            },
        )
        print(f"DEBUG ECS RESPONSE: {json.dumps(response_ecs, default=str)}")

    except Exception as e:
        print(f"!!! ERROR LANZANDO ECS: {str(e)}")
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=f"tasks/{task_id}/status=error",
            Body=json.dumps({"error": f"Error al lanzar worker: {str(e)}"}).encode("utf-8"),
        )
        raise e

    return response(
        202,
        {"task_id": task_id, "status": "processing", "message": "Descarga iniciada correctamente"},
    )


def get_status(task_id: str) -> dict:
    """
    GET /status/{id}
    Consulta el estado de una tarea leyendo los archivos en S3.
    """
    prefix = f"tasks/{task_id}/"

    result = s3_client.list_objects_v2(Bucket=S3_BUCKET, Prefix=prefix)

    if "Contents" not in result:
        return response(
            404, {"task_id": task_id, "status": "not_found", "message": "Tarea no encontrada"}
        )

    keys = [obj["Key"] for obj in result["Contents"]]
    status_key = next((k for k in keys if "status=" in k), None)
    mp3_exists = any("audio.mp3" in k for k in keys)

    # PARCHE S3 consistencia eventual:
    # Si el MP3 existe pero el estado aún no refleja completed
    # por lag de S3, devolvemos completed directamente.
    # El MP3 es la fuente de verdad real de que la tarea completó.
    if mp3_exists and (status_key is None or "status=processing" in status_key):
        mp3_key = f"tasks/{task_id}/audio.mp3"
        presigned_url = s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": mp3_key},
            ExpiresIn=900,
        )
        return response(
            200,
            {
                "task_id": task_id,
                "status": "completed",
                "url": presigned_url,
                "message": "MP3 listo para descargar",
            },
        )

    if status_key is None:
        return response(
            404, {"task_id": task_id, "status": "not_found", "message": "Tarea no encontrada"}
        )

    if "status=processing" in status_key:
        return response(
            200, {"task_id": task_id, "status": "processing", "message": "Procesando audio..."}
        )

    if "status=error" in status_key:
        error_obj = s3_client.get_object(Bucket=S3_BUCKET, Key=status_key)
        error_data = json.loads(error_obj["Body"].read().decode("utf-8"))
        return response(
            200,
            {
                "task_id": task_id,
                "status": "error",
                "message": error_data.get("error", "Error desconocido"),
            },
        )

    if "status=completed" in status_key:
        mp3_key = f"tasks/{task_id}/audio.mp3"
        presigned_url = s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": mp3_key},
            ExpiresIn=900,
        )
        return response(
            200,
            {
                "task_id": task_id,
                "status": "completed",
                "url": presigned_url,
                "message": "MP3 listo para descargar",
            },
        )

    return response(500, {"task_id": task_id, "status": "unknown", "message": "Estado desconocido"})


def lambda_handler(event: dict, context) -> dict:
    """
    Punto de entrada de Lambda.
    API Gateway envía el evento completo con método HTTP y path.
    """
    print(f"DEBUG EVENT: {json.dumps(event)}")  # <--- AÑADE ESTO

    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    full_path = event.get("requestContext", {}).get("http", {}).get("path", "")
    # ESTO ES LO NUEVO:
    # Si el path es "/dev/download", esto lo convierte en "/download"
    # Si el path es "/download", se queda igual o.
    path = full_path.replace("/dev", "", 1)
    # Health check
    if method == "GET" and path == "/health":
        return response(200, {"status": "healthy"})

    # POST /download — iniciar descarga
    if method == "POST" and path == "/download":
        body = json.loads(event.get("body", "{}"))
        url = body.get("url", "").strip()

        if not url:
            return response(400, {"message": "El campo url es obligatorio"})

        if "youtube.com" not in url and "youtu.be" not in url:
            return response(400, {"message": "La URL no es de YouTube"})

        return create_task(url)

    # GET /status/{id} — consultar estado
    if method == "GET" and "/status/" in path:
        task_id = path.split("/status/")[-1]
        return get_status(task_id)

    return response(404, {"message": "Ruta no encontrada"})
