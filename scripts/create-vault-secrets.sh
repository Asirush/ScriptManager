#!/usr/bin/env bash
#
# Usage:
#   ./push-to-vault-subpaths.sh <vault_addr> <vault_token> <configmap_file> <environment> <services_list_file> [--debug]
#

# Description:
# ------------------------------------------------------------------------------
# This script pushes service-specific environment variables from a Kubernetes-style
# ConfigMap into HashiCorp Vault as secrets.
#
# It is designed to help DevOps/SRE teams synchronize their ConfigMap-based
# application environment variables with Vault in a structured and automated way.
#
# The script performs the following actions:
#
# 1. Reads a list of allowed services from a YAML file (format: `services:` with a list).
# 2. Parses a provided ConfigMap YAML file and extracts variables named like:
#      {SERVICE_NAME}_{ENV_VAR}:
#    For example: `USERSAPI_DB_PASSWORD: mysecret`
#
# 3. Filters out variables not belonging to the allowed services.
#
# 4. Converts the service name and environment (e.g., `DEV`, `STAGING`) to lowercase.
#    It then constructs a Vault secret path in the format:
#       secret/{service}-{environment}
#    For example:
#       secret/usersapi-develop
#
# 5. All variables for each service are combined and written to that Vault path
#    as a single secret using `vault kv put`.
#
#    Example:
#       vault kv put secret/usersapi-develop USERSAPI_DB_PASSWORD=mysecret OTHER_VAR=abc
#
# 6. Optionally, if you pass `--debug`, it will log all parsed and filtered
#    variables for transparency and troubleshooting.
#
# Requirements:
#   - `vault` CLI must be installed and accessible in your environment.
#   - VAULT_ADDR and VAULT_TOKEN must be valid for the Vault instance.
#   - ConfigMap file should follow typical Kubernetes format (e.g., key-value pairs under `data:`).
#   - services-list YAML file should include a `services:` list.
#
# Use Case:
#   This script is ideal for teams migrating environment-specific config values
#   from plaintext or ConfigMap files into Vault for better security and dynamic access.
#
# Example call:
#   ./push-to-vault-subpaths.sh \
#       "https://vault.example.com" \
#       "s.myToken123" \
#       "./configmap.yaml" \
#       "DEVELOP" \
#       "./services-list.yaml" \
#       --debug
#
# After this runs, your Vault will contain entries like:
#   secret/usersapi-develop
#     - USERSAPI_DB_PASSWORD: <value>
#     - USERSAPI_API_KEY: <value>
# ------------------------------------------------------------------------------

set -euo pipefail

log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

VAULT_ADDR="${1:-}"
VAULT_TOKEN="${2:-}"
CONFIGMAP_FILE="${3:-}"
ENVIRONMENT="${4:-}"
SERVICES_LIST_FILE="${5:-}"
DEBUG_MODE="${6:-}"

if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$CONFIGMAP_FILE" ] || [ -z "$ENVIRONMENT" ] || [ -z "$SERVICES_LIST_FILE" ]; then
  echo "Usage: $0 <vault_addr> <vault_token> <configmap_file> <environment> <services_list_file> [--debug]"
  exit 1
fi

ENVIRONMENT="$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"
export VAULT_ADDR VAULT_TOKEN

log "INFO" "Starting push-to-vault-subpaths.sh"
log "INFO" "Vault address: $VAULT_ADDR"
log "INFO" "Environment: $ENVIRONMENT"
log "INFO" "ConfigMap file: $CONFIGMAP_FILE"
log "INFO" "Services list file: $SERVICES_LIST_FILE"

DEBUG=false
if [ "$DEBUG_MODE" == "--debug" ]; then
  DEBUG=true
  log "DEBUG" "Debug mode is ON."
fi

log "INFO" "Verifying Vault connectivity..."
vault status >/dev/null || { log "ERROR" "Cannot connect to Vault."; exit 1; }

log "INFO" "Verifying Vault token..."
vault token lookup >/dev/null || { log "ERROR" "Invalid Vault token."; exit 1; }

log "INFO" "Vault verified."

# Load allowed services
allowed_services=()
in_services_block=false
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*services: ]]; then
    in_services_block=true
    continue
  fi
  if $in_services_block; then
    trimmed="$(echo "$line" | xargs)"
    if [[ "$trimmed" =~ ^- ]]; then
      svc="${trimmed#- }"
      svc="$(echo "$svc" | tr '[:upper:]' '[:lower:]')"
      allowed_services+=("$svc")
    elif [ -z "$trimmed" ]; then
      break
    fi
  fi
done < "$SERVICES_LIST_FILE"

if [ "${#allowed_services[@]}" -eq 0 ]; then
  log "WARN" "No allowed services found. Exiting."
  exit 0
fi

log "INFO" "Allowed services: ${allowed_services[*]}"

declare -A allowed_map
for svc in "${allowed_services[@]}"; do
  allowed_map["$svc"]=1
done

declare -A service_vars

in_data_section=false
log "INFO" "Parsing ConfigMap..."

envsubst < "$CONFIGMAP_FILE" | while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*data: ]]; then
    in_data_section=true
    continue
  fi
  if $in_data_section; then
    stripped_line="$(echo "$line" | xargs || true)"
    [[ -z "$stripped_line" || "$stripped_line" != *":"* ]] && continue

    key="${stripped_line%%:*}"
    value="${stripped_line#*:}"
    key="$(echo "$key" | xargs || true)"
    value="$(echo "$value" | xargs || true)"

    $DEBUG && log "DEBUG" "Found variable: $key = $value"

    if [[ "$key" == *"_"* ]]; then
      service_prefix="${key%%_*}"
      lower_svc="$(echo "$service_prefix" | tr '[:upper:]' '[:lower:]')"
      if [[ -n "${allowed_map["$lower_svc"]:-}" ]]; then
        full_key="${key}"
        if [ -z "${service_vars[$lower_svc]:-}" ]; then
          service_vars[$lower_svc]="${full_key}=${value}"
        else
          service_vars[$lower_svc]="${service_vars[$lower_svc]}|${full_key}=${value}"
        fi
        $DEBUG && log "DEBUG" "✔ Added to $lower_svc: $full_key"
      else
        $DEBUG && log "DEBUG" "❌ Skipped: $key (Not allowed)"
      fi
    fi
  fi
done

# Write to Vault
for svc in "${!service_vars[@]}"; do
  vault_path="secret/${svc}-${ENVIRONMENT}"
  $DEBUG && log "DEBUG" "Preparing to write to: $vault_path"

  IFS='|' read -r -a kv_array <<< "${service_vars[$svc]}"
  args=()
  for kv in "${kv_array[@]}"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    args+=("$k=$v")
  done

  log "INFO" "Writing ${#args[@]} variables to Vault path: $vault_path"
  vault kv put "$vault_path" "${args[@]}"
done

log "INFO" "All secrets written successfully."
exit 0
