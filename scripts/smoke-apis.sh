#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_PATH="${ROOT_DIR}/specs/catalog.json"

STRICT_MODE=0
DRY_RUN=0
TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-20}"
CONNECT_TIMEOUT_SECONDS="${SMOKE_CONNECT_TIMEOUT_SECONDS:-5}"
SPEC_FILTERS=()
DEVELOPER_TOKEN_URL_DEFAULT="https://api.korewireless.com/Api/api/token"
BUILD_TOKEN_URL_DEFAULT="https://api.korewireless.com/api-services/v1/auth/token"
BUILD_TOKEN_CACHE=""
DEVELOPER_TOKEN_CACHE=""

usage() {
  cat <<'EOF'
Run lightweight HTTP smoke checks for cataloged APIs.

Usage:
  ./scripts/smoke-apis.sh [options]

Options:
  --spec <id[,id...]>   Only run for specific spec ID(s). Repeatable.
  --strict              Pass only on 2xx responses (default: 2xx/3xx/4xx pass).
  --dry-run             Show planned requests without executing them.
  --timeout <seconds>   Max request time (default: 20 or SMOKE_TIMEOUT_SECONDS).
  --help                Show this help.

Auth environment variables (optional):
  Common:
    KORE_BEARER_TOKEN
    KORE_API_KEY
  Build portal (Super SIM / Programmable Wireless / API Clients / IAM / Webhook):
    KORE_BUILD_BEARER_TOKEN
    KORE_BUILD_API_KEY
    KORE_BUILD_CLIENT_ID / KORE_BUILD_CLIENT_SECRET
    (KORE_CLIENT_ID / KORE_CLIENT_SECRET are accepted aliases)
  Developer portal (ConnectivityPro / SMS):
    KORE_DEVELOPER_BEARER_TOKEN
    KORE_DEVELOPER_API_KEY
    KORE_DEVELOPER_CLIENT_ID / KORE_DEVELOPER_CLIENT_SECRET
EOF
}

trim_spaces() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

add_spec_filters() {
  local raw="$1"
  local part
  local split_parts=()
  IFS=',' read -r -a split_parts <<< "$raw"
  for part in "${split_parts[@]}"; do
    part="$(trim_spaces "$part")"
    if [[ -n "$part" ]]; then
      SPEC_FILTERS+=("$part")
    fi
  done
}

spec_matches_filter() {
  local spec_id="$1"
  local filter
  if [[ "${#SPEC_FILTERS[@]}" -eq 0 ]]; then
    return 0
  fi
  for filter in "${SPEC_FILTERS[@]}"; do
    if [[ "$filter" == "$spec_id" ]]; then
      return 0
    fi
  done
  return 1
}

extract_spec_token_url() {
  local spec_json_path="$1"
  jq -r '
    [
      (.components.securitySchemes // {})
      | to_entries[]?
      | (.value.flows // {})
      | to_entries[]?
      | .value.tokenUrl?
    ]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  ' "$spec_json_path"
}

portal_for_spec() {
  local spec_id="$1"
  local token_url="$2"
  if [[ "$token_url" == "$DEVELOPER_TOKEN_URL_DEFAULT" ]]; then
    printf 'developer'
    return
  fi
  if [[ "$token_url" == "$BUILD_TOKEN_URL_DEFAULT" ]]; then
    printf 'build'
    return
  fi
  if [[ "$spec_id" == "api-clients-token-v1" ]]; then
    printf 'build'
    return
  fi
  printf 'unknown'
}

fetch_access_token() {
  local token_url="$1"
  local client_id="$2"
  local client_secret="$3"
  local response token

  if [[ -z "$token_url" || -z "$client_id" || -z "$client_secret" ]]; then
    return 1
  fi

  set +e
  response="$(curl -sS \
    --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
    --max-time "${TIMEOUT_SECONDS}" \
    -X POST "${token_url}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=${client_id}" \
    --data-urlencode "client_secret=${client_secret}")"
  local curl_exit=$?
  set -e
  if [[ "${curl_exit}" -ne 0 ]]; then
    return 1
  fi

  token="$(printf '%s' "${response}" | jq -r '.access_token // empty' 2>/dev/null || true)"
  if [[ -z "${token}" || "${token}" == "null" ]]; then
    return 1
  fi
  printf '%s' "${token}"
}

select_smoke_operation() {
  local spec_json_path="$1"
  jq -r '
    .paths
    | to_entries
    | map(
        . as $p
        | ($p.value.parameters // []) as $path_params
        | (
            $p.value
            | to_entries
            | map(
                select(.key | test("^(get|post|put|patch|delete|head)$"))
                | {
                    method: (.key | ascii_upcase),
                    method_rank: (
                      if .key == "get" then 0
                      elif .key == "head" then 1
                      elif .key == "post" then 2
                      elif .key == "put" then 3
                      elif .key == "patch" then 4
                      else 6
                      end
                    ),
                    path: $p.key,
                    path_rank: (
                      if ($p.key | test("/ping$")) then 0
                      elif ($p.key | test("ping")) then 1
                      elif ($p.key | test("health")) then 2
                      else 3
                      end
                    ),
                    required_params: (
                      ($path_params + (.value.parameters // []))
                      | map(select(.required == true))
                      | length
                    ),
                    required_body: (
                      if ((.value.requestBody // {}) | type) == "object"
                         and ((.value.requestBody.required // false) == true)
                      then 1
                      else 0
                      end
                    )
                  }
              )
          )
      )
    | add
    | if . == null or length == 0 then
        empty
      else
        sort_by((.required_params + .required_body), .path_rank, .method_rank, .path)[0]
        | [.method, .path, ((.required_params + .required_body) | tostring)]
        | @tsv
      end
  ' "$spec_json_path"
}

normalize_smoke_path() {
  local raw_path="$1"
  printf '%s' "$raw_path" | sed -E 's/\{[^}]+\}/test/g'
}

is_pass_code() {
  local code="$1"
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    [[ "$code" =~ ^2[0-9][0-9]$ ]]
  else
    [[ "$code" =~ ^[234][0-9][0-9]$ ]]
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec|-s)
      add_spec_filters "${2:-}"
      shift 2
      ;;
    --strict)
      STRICT_MODE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${CATALOG_PATH}" ]]; then
  echo "Catalog not found: ${CATALOG_PATH}" >&2
  exit 1
fi

BUILD_CLIENT_ID="${KORE_BUILD_CLIENT_ID:-${KORE_CLIENT_ID:-}}"
BUILD_CLIENT_SECRET="${KORE_BUILD_CLIENT_SECRET:-${KORE_CLIENT_SECRET:-}}"
DEVELOPER_CLIENT_ID="${KORE_DEVELOPER_CLIENT_ID:-}"
DEVELOPER_CLIENT_SECRET="${KORE_DEVELOPER_CLIENT_SECRET:-}"

common_bearer_state="no"
build_bearer_state="no"
developer_bearer_state="no"
if [[ -n "${KORE_BEARER_TOKEN:-}" ]]; then
  common_bearer_state="yes"
fi
if [[ -n "${KORE_BUILD_BEARER_TOKEN:-}" ]]; then
  build_bearer_state="yes"
fi
if [[ -n "${KORE_DEVELOPER_BEARER_TOKEN:-}" ]]; then
  developer_bearer_state="yes"
fi

common_api_key_state="no"
build_api_key_state="no"
developer_api_key_state="no"
if [[ -n "${KORE_API_KEY:-}" ]]; then
  common_api_key_state="yes"
fi
if [[ -n "${KORE_BUILD_API_KEY:-}" ]]; then
  build_api_key_state="yes"
fi
if [[ -n "${KORE_DEVELOPER_API_KEY:-}" ]]; then
  developer_api_key_state="yes"
fi

build_creds_state="no"
developer_creds_state="no"
if [[ -n "${BUILD_CLIENT_ID}" && -n "${BUILD_CLIENT_SECRET}" ]]; then
  build_creds_state="yes"
fi
if [[ -n "${DEVELOPER_CLIENT_ID}" && -n "${DEVELOPER_CLIENT_SECRET}" ]]; then
  developer_creds_state="yes"
fi

echo "Running smoke checks (strict=${STRICT_MODE}, dry_run=${DRY_RUN}, timeout=${TIMEOUT_SECONDS}s)"
echo "Auth config: common(bearer=${common_bearer_state},api_key=${common_api_key_state}) build(bearer=${build_bearer_state},api_key=${build_api_key_state},creds=${build_creds_state}) developer(bearer=${developer_bearer_state},api_key=${developer_api_key_state},creds=${developer_creds_state})"
printf "%-6s %-30s %-10s %-6s %s\n" "RESULT" "SPEC ID" "PORTAL" "HTTP" "REQUEST"

checked=0
passed=0
failed=0
skipped=0

while IFS=$'\t' read -r spec_id base_url spec_json_rel; do
  if ! spec_matches_filter "$spec_id"; then
    continue
  fi

  checked=$((checked + 1))
  spec_json_path="${ROOT_DIR}/${spec_json_rel}"

  if [[ ! -f "${spec_json_path}" ]]; then
    printf "%-6s %-30s %-10s %-6s %s\n" "FAIL" "${spec_id}" "-" "-" "spec file not found: ${spec_json_rel}"
    failed=$((failed + 1))
    continue
  fi

  token_url="$(extract_spec_token_url "${spec_json_path}" || true)"
  if [[ -z "${token_url}" && "${spec_id}" == "api-clients-token-v1" ]]; then
    token_url="${BUILD_TOKEN_URL_DEFAULT}"
  fi
  portal="$(portal_for_spec "${spec_id}" "${token_url}")"

  selection="$(select_smoke_operation "${spec_json_path}" || true)"
  if [[ -z "${selection}" ]]; then
    printf "%-6s %-30s %-10s %-6s %s\n" "SKIP" "${spec_id}" "${portal}" "-" "no HTTP operation found in spec"
    skipped=$((skipped + 1))
    continue
  fi

  method=""
  raw_path=""
  score=""
  IFS=$'\t' read -r method raw_path score <<< "${selection}"
  smoke_path="$(normalize_smoke_path "${raw_path}")"
  request_url="${base_url%/}${smoke_path}"

  bearer_token=""
  api_key_value=""

  case "${portal}" in
    developer)
      bearer_token="${KORE_DEVELOPER_BEARER_TOKEN:-${KORE_BEARER_TOKEN:-}}"
      api_key_value="${KORE_DEVELOPER_API_KEY:-${KORE_API_KEY:-}}"
      if [[ -z "${bearer_token}" && -n "${DEVELOPER_CLIENT_ID}" && -n "${DEVELOPER_CLIENT_SECRET}" ]]; then
        if [[ -z "${DEVELOPER_TOKEN_CACHE}" ]]; then
          DEVELOPER_TOKEN_CACHE="$(fetch_access_token "${DEVELOPER_TOKEN_URL_DEFAULT}" "${DEVELOPER_CLIENT_ID}" "${DEVELOPER_CLIENT_SECRET}" || true)"
        fi
        bearer_token="${DEVELOPER_TOKEN_CACHE}"
      fi
      ;;
    build)
      bearer_token="${KORE_BUILD_BEARER_TOKEN:-${KORE_BEARER_TOKEN:-}}"
      api_key_value="${KORE_BUILD_API_KEY:-${KORE_API_KEY:-}}"
      if [[ -z "${bearer_token}" && -n "${BUILD_CLIENT_ID}" && -n "${BUILD_CLIENT_SECRET}" ]]; then
        if [[ -z "${BUILD_TOKEN_CACHE}" ]]; then
          BUILD_TOKEN_CACHE="$(fetch_access_token "${BUILD_TOKEN_URL_DEFAULT}" "${BUILD_CLIENT_ID}" "${BUILD_CLIENT_SECRET}" || true)"
        fi
        bearer_token="${BUILD_TOKEN_CACHE}"
      fi
      ;;
    *)
      bearer_token="${KORE_BEARER_TOKEN:-}"
      api_key_value="${KORE_API_KEY:-}"
      ;;
  esac

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf "%-6s %-30s %-10s %-6s %s\n" "PLAN" "${spec_id}" "${portal}" "-" "${method} ${request_url}"
    continue
  fi

  curl_args=(
    -sS
    -o /dev/null
    -w "%{http_code}"
    --connect-timeout "${CONNECT_TIMEOUT_SECONDS}"
    --max-time "${TIMEOUT_SECONDS}"
    -X "${method}"
  )

  if [[ -n "${bearer_token}" && "${spec_id}" != "api-clients-token-v1" ]]; then
    curl_args+=(-H "Authorization: Bearer ${bearer_token}")
  fi
  if [[ -n "${api_key_value}" ]]; then
    curl_args+=(-H "x-api-key: ${api_key_value}")
  fi
  if [[ "${spec_id}" == "api-clients-token-v1" && -n "${BUILD_CLIENT_ID}" && -n "${BUILD_CLIENT_SECRET}" ]]; then
    curl_args+=(
      -H "Content-Type: application/x-www-form-urlencoded"
      --data-urlencode "grant_type=client_credentials"
      --data-urlencode "client_id=${BUILD_CLIENT_ID}"
      --data-urlencode "client_secret=${BUILD_CLIENT_SECRET}"
    )
  fi

  err_file="$(mktemp)"
  set +e
  http_code="$(curl "${curl_args[@]}" "${request_url}" 2>"${err_file}")"
  curl_exit=$?
  set -e
  curl_err="$(cat "${err_file}")"
  rm -f "${err_file}"

  if [[ "${curl_exit}" -ne 0 ]]; then
    printf "%-6s %-30s %-10s %-6s %s\n" "FAIL" "${spec_id}" "${portal}" "000" "${method} ${request_url} (curl exit ${curl_exit})"
    if [[ -n "${curl_err}" ]]; then
      echo "       ${curl_err}"
    fi
    failed=$((failed + 1))
    continue
  fi

  if is_pass_code "${http_code}"; then
    printf "%-6s %-30s %-10s %-6s %s\n" "PASS" "${spec_id}" "${portal}" "${http_code}" "${method} ${request_url}"
    passed=$((passed + 1))
  else
    printf "%-6s %-30s %-10s %-6s %s\n" "FAIL" "${spec_id}" "${portal}" "${http_code}" "${method} ${request_url}"
    failed=$((failed + 1))
  fi
done < <(jq -r '.[] | [.id, .base_url, .json] | @tsv' "${CATALOG_PATH}")

if [[ "${checked}" -eq 0 ]]; then
  echo "No specs matched the requested filter." >&2
  exit 1
fi

echo ""
echo "Summary: checked=${checked}, passed=${passed}, failed=${failed}, skipped=${skipped}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  exit 0
fi

if [[ "${failed}" -gt 0 ]]; then
  exit 1
fi
