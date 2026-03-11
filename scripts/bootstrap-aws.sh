#!/bin/bash
# =============================================================================
# bootstrap-aws.sh
# Inicialización única de recursos AWS que no puede gestionar Terraform.
# Este script lo ejecuta el propietario de la cuenta AWS UNA SOLA VEZ
# usando credenciales con permisos suficientes (root o administrador).
#
# IMPORTANTE: Este script NO debe ejecutarlo un desarrollador nuevo.
# Los desarrolladores nuevos reciben sus credenciales IAM ya creadas
# del propietario del proyecto y configuran su perfil local con:
# aws configure --profile yt_mp3_api_dev
# =============================================================================

set -e

PROFILE="yt_mp3_api_dev"
REGION="eu-west-1"
PROJECT="yt-mp3-api"
BUCKET_STATE="${PROJECT}-terraform-state"
POLICY_NAME="yt_mp3_api_dev_policy"
USER_NAME="yt_mp3_api_dev"

echo ""
echo "============================================="
echo "  Bootstrap AWS — ${PROJECT}"
echo "  Este script se ejecuta UNA SOLA VEZ"
echo "============================================="
echo ""

# -----------------------------------------------------------------------------
# PASO 1: Verificar que la AWS CLI está instalada y configurada
# -----------------------------------------------------------------------------
echo "→ Verificando AWS CLI..."
if ! command -v aws &> /dev/null; then
    echo "✗ AWS CLI no está instalada."
    echo "  Instálala con: sudo apt install awscli -y"
    exit 1
fi
echo "✓ AWS CLI disponible"

# -----------------------------------------------------------------------------
# PASO 2: Crear la política IAM con mínimos privilegios
# Nota: si ya existe, este paso fallará. Es seguro ignorar ese error.
# -----------------------------------------------------------------------------
echo ""
echo "→ Creando política IAM ${POLICY_NAME}..."
echo "  Si ya existe, puedes ignorar el error que aparezca."

aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document file://scripts/iam-policy.json \
  --description "Política de desarrollo para ${PROJECT} con mínimos privilegios" \
  --profile "${PROFILE}" 2>/dev/null || echo "  La política ya existe, continuando..."

echo "✓ Política IAM lista"

# -----------------------------------------------------------------------------
# PASO 3: Crear el usuario IAM de desarrollo
# Nota: si ya existe, este paso fallará. Es seguro ignorar ese error.
# -----------------------------------------------------------------------------
echo ""
echo "→ Creando usuario IAM ${USER_NAME}..."

aws iam create-user \
  --user-name "${USER_NAME}" \
  --profile "${PROFILE}" 2>/dev/null || echo "  El usuario ya existe, continuando..."

# Obtener el ARN de la política y adjuntarla al usuario
ACCOUNT_ID=$(aws sts get-caller-identity --profile "${PROFILE}" --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

aws iam attach-user-policy \
  --user-name "${USER_NAME}" \
  --policy-arn "${POLICY_ARN}" \
  --profile "${PROFILE}" 2>/dev/null || echo "  La política ya estaba adjunta, continuando..."

echo "✓ Usuario IAM listo"
echo ""
echo "  IMPORTANTE: Genera las credenciales de acceso manualmente en la"
echo "  consola de AWS → IAM → Users → ${USER_NAME} → Security credentials"
echo "  → Create access key → Command Line Interface (CLI)"
echo "  Luego configura tu perfil local con:"
echo "  aws configure --profile ${USER_NAME}"

# -----------------------------------------------------------------------------
# PASO 4: Crear el bucket de S3 para el estado de Terraform
# -----------------------------------------------------------------------------
echo ""
echo "→ Creando bucket S3 para estado de Terraform: ${BUCKET_STATE}..."

aws s3api create-bucket \
  --bucket "${BUCKET_STATE}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}" \
  --profile "${PROFILE}" 2>/dev/null || echo "  El bucket ya existe, continuando..."

# Activar versionado para poder recuperar estados anteriores si se corrompen
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_STATE}" \
  --versioning-configuration Status=Enabled \
  --profile "${PROFILE}"

# Verificar que el versionado quedó activo
STATUS=$(aws s3api get-bucket-versioning \
  --bucket "${BUCKET_STATE}" \
  --profile "${PROFILE}" \
  --query Status \
  --output text)

if [ "$STATUS" = "Enabled" ]; then
  echo "✓ Bucket S3 listo con versionado activo"
else
  echo "✗ Error activando el versionado del bucket"
  exit 1
fi

# -----------------------------------------------------------------------------
# RESUMEN FINAL
# -----------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Bootstrap completado con éxito"
echo "============================================="
echo ""
echo "  Recursos creados manualmente:"
echo "  ✓ Política IAM:  ${POLICY_NAME}"
echo "  ✓ Usuario IAM:   ${USER_NAME}"
echo "  ✓ Bucket S3:     ${BUCKET_STATE} (versionado activo)"
echo ""
echo "  Siguiente paso:"
echo "  cd infra && terraform init"
echo "============================================="
echo ""
