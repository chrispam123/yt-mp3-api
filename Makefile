
# =============================================================================
# YT-MP3-API — Makefile
# Uso: make <comando>
# =============================================================================

.PHONY: help install update lint build-worker deploy package-lambda run clean

help:
	@echo ""
	@echo "  YT-MP3-API — Comandos disponibles"
	@echo "  ==================================="
	@echo "  make install          Crea el entorno virtual e instala dependencias"
	@echo "  make update           Recompila requirements.txt y actualiza dependencias"
	@echo "  make lint             Ejecuta pre-commit con ruff sobre todo el código"
	@echo "  make build-worker     Construye la imagen Docker del worker de Fargate"
	@echo "  make deploy           Sube la imagen Docker a ECR (CD manual)"
	@echo "  make package-lambda   Empaqueta el código Lambda en un zip para Terraform"
	@echo "  make run              Ejecuta el worker localmente para desarrollo"
	@echo "  make clean            Elimina entorno virtual y artefactos generados"
	@echo ""

install:
	@echo "→ Creando entorno virtual..."
	python3 -m venv .venv
	@echo "→ Instalando dependencias..."
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install pip-tools
	.venv/bin/pip-sync requirements.txt
	@echo "→ Instalando hooks de pre-commit..."
	.venv/bin/pre-commit install
	@echo "✓ Entorno listo. Actívalo con: source .venv/bin/activate"

update:
	@echo "→ Recompilando dependencias..."
	.venv/bin/pip-compile requirements.in
	.venv/bin/pip-sync requirements.txt
	@echo "✓ Dependencias actualizadas"

lint:
	@echo "→ Ejecutando pre-commit con ruff..."
	.venv/bin/pre-commit run --all-files
	@echo "✓ Lint completado"

build-worker:
	@echo "→ Construyendo imagen Docker del worker..."
	docker build -t yt-mp3-api-worker .
	@echo "✓ Imagen construida: yt-mp3-api-worker"

deploy:
	@echo "→ Autenticando en ECR..."
	aws ecr get-login-password \
		--region eu-west-1 \
		--profile yt_mp3_api_dev | \
		docker login \
		--username AWS \
		--password-stdin \
		$(shell aws ecr describe-repositories \
			--repository-names yt-mp3-api-worker \
			--region eu-west-1 \
			--profile yt_mp3_api_dev \
			--query 'repositories[0].repositoryUri' \
			--output text)
	@echo "→ Etiquetando imagen..."
	docker tag yt-mp3-api-worker:latest \
		$(shell aws ecr describe-repositories \
			--repository-names yt-mp3-api-worker \
			--region eu-west-1 \
			--profile yt_mp3_api_dev \
			--query 'repositories[0].repositoryUri' \
			--output text):latest
	@echo "→ Subiendo imagen a ECR..."
	docker push \
		$(shell aws ecr describe-repositories \
			--repository-names yt-mp3-api-worker \
			--region eu-west-1 \
			--profile yt_mp3_api_dev \
			--query 'repositories[0].repositoryUri' \
			--output text):latest
	@echo "✓ Imagen subida a ECR correctamente"

package-lambda:
	@echo "→ Empaquetando código Lambda..."
	mkdir -p build
	zip -r build/lambda_placeholder.zip src/lambda/ src/shared/
	@echo "✓ Lambda empaquetada en build/lambda_placeholder.zip"

run:
	@echo "→ Ejecutando worker localmente..."
	TASK_ID=test-local \
	URL=$(URL) \
	S3_BUCKET=local-test \
	AWS_REGION=eu-west-1 \
	.venv/bin/python src/worker/worker.py

clean:
	@echo "→ Eliminando entorno virtual y artefactos..."
	rm -rf .venv build
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	@echo "✓ Limpieza completada"
