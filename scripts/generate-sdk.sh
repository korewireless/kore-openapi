#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_PATH="${ROOT_DIR}/specs/catalog.json"
GENERATOR_IMAGE="${OPENAPI_GENERATOR_IMAGE:-openapitools/openapi-generator-cli:v7.12.0}"

usage() {
  cat <<'EOF'
Generate SDKs/libraries from a cataloged OpenAPI spec.

Usage:
  ./scripts/generate-sdk.sh --spec <spec-id> --generator <generator-name> [options]

Options:
  --output <repo-relative-path>         Output directory (default: generated/<spec-id>/<generator>)
  --package-name <name>                 Adds packageName=<name> to generator additional properties
  --additional-properties <k=v,...>     Extra generator additional properties
  --                                    Pass remaining args directly to openapi-generator generate
  --help                                Show this help

Examples:
  ./scripts/generate-sdk.sh --spec supersim-v1 --generator typescript-fetch
  ./scripts/generate-sdk.sh --spec webhook-v1 --generator python --package-name kore_webhook
EOF
}

SPEC_ID=""
GENERATOR=""
OUTPUT_PATH=""
PACKAGE_NAME=""
ADDITIONAL_PROPERTIES=""
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec|-s)
      SPEC_ID="${2:-}"
      shift 2
      ;;
    --generator|-g)
      GENERATOR="${2:-}"
      shift 2
      ;;
    --output|-o)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --package-name)
      PACKAGE_NAME="${2:-}"
      shift 2
      ;;
    --additional-properties)
      ADDITIONAL_PROPERTIES="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      PASSTHROUGH_ARGS=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${SPEC_ID}" || -z "${GENERATOR}" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "${CATALOG_PATH}" ]]; then
  echo "Catalog not found: ${CATALOG_PATH}" >&2
  exit 1
fi

SPEC_PATH="$(jq -r --arg id "${SPEC_ID}" '.[] | select(.id == $id) | .yaml' "${CATALOG_PATH}")"

if [[ -z "${SPEC_PATH}" || "${SPEC_PATH}" == "null" ]]; then
  echo "Unknown spec ID: ${SPEC_ID}" >&2
  echo "Available IDs:" >&2
  jq -r '.[].id' "${CATALOG_PATH}" >&2
  exit 1
fi

if [[ -z "${OUTPUT_PATH}" ]]; then
  OUTPUT_PATH="generated/${SPEC_ID}/${GENERATOR}"
fi

if [[ "${OUTPUT_PATH}" == /* ]]; then
  echo "Output path must be repository-relative: ${OUTPUT_PATH}" >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/${OUTPUT_PATH}"

PROPERTIES="${ADDITIONAL_PROPERTIES}"
if [[ -n "${PACKAGE_NAME}" ]]; then
  if [[ -n "${PROPERTIES}" ]]; then
    PROPERTIES="${PROPERTIES},packageName=${PACKAGE_NAME}"
  else
    PROPERTIES="packageName=${PACKAGE_NAME}"
  fi
fi

DOCKER_ARGS=(
  generate
  -i "/local/${SPEC_PATH}"
  -g "${GENERATOR}"
  -o "/local/${OUTPUT_PATH}"
)

LOCAL_ARGS=(
  generate
  -i "${ROOT_DIR}/${SPEC_PATH}"
  -g "${GENERATOR}"
  -o "${ROOT_DIR}/${OUTPUT_PATH}"
)

if [[ -n "${PROPERTIES}" ]]; then
  DOCKER_ARGS+=(--additional-properties "${PROPERTIES}")
  LOCAL_ARGS+=(--additional-properties "${PROPERTIES}")
fi

if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
  DOCKER_ARGS+=("${PASSTHROUGH_ARGS[@]}")
  LOCAL_ARGS+=("${PASSTHROUGH_ARGS[@]}")
fi

if command -v docker >/dev/null 2>&1; then
  echo "Using Docker image: ${GENERATOR_IMAGE}"
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "${ROOT_DIR}:/local" \
    "${GENERATOR_IMAGE}" \
    "${DOCKER_ARGS[@]}"
elif command -v openapi-generator-cli >/dev/null 2>&1; then
  echo "Using local openapi-generator-cli"
  openapi-generator-cli "${LOCAL_ARGS[@]}"
elif command -v npx >/dev/null 2>&1; then
  echo "Using npx @openapitools/openapi-generator-cli"
  (
    cd "${ROOT_DIR}"
    npx --yes @openapitools/openapi-generator-cli "${LOCAL_ARGS[@]}"
  )
else
  echo "No generator runtime found." >&2
  echo "Install Docker, openapi-generator-cli, or Node.js+npx." >&2
  exit 1
fi

echo "Generated SDK at: ${OUTPUT_PATH}"
