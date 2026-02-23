#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_PATH="${ROOT_DIR}/specs/catalog.json"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/list-specs.sh             # table output
  ./scripts/list-specs.sh --ids       # ID list only
  ./scripts/list-specs.sh --json      # raw catalog JSON
EOF
}

if [[ ! -f "${CATALOG_PATH}" ]]; then
  echo "Catalog not found: ${CATALOG_PATH}" >&2
  exit 1
fi

case "${1:-}" in
  "")
    printf "%-32s %-60s %s\n" "SPEC ID" "YAML" "BASE URL"
    jq -r '.[] | [.id, .yaml, .base_url] | @tsv' "${CATALOG_PATH}" \
      | while IFS=$'\t' read -r spec_id yaml_path base_url; do
          printf "%-32s %-60s %s\n" "${spec_id}" "${yaml_path}" "${base_url}"
        done
    ;;
  --ids)
    jq -r '.[].id' "${CATALOG_PATH}"
    ;;
  --json)
    cat "${CATALOG_PATH}"
    ;;
  --help|-h)
    usage
    ;;
  *)
    echo "Unknown option: ${1}" >&2
    usage >&2
    exit 1
    ;;
esac
