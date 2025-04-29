#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="./scripts"
INSTALL_DIR="/usr/local/bin"
LOG_FILE="$HOME/update.log"
DRY_RUN=false

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  fi
done

log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

log "INFO" "Starting update..."
log "INFO" "Source: $SCRIPTS_DIR -> Target: $INSTALL_DIR"
$DRY_RUN && log "INFO" "Dry-run mode: No files will be overwritten."

if [ ! -d "$SCRIPTS_DIR" ]; then
  log "ERROR" "Scripts directory not found!"
  exit 1
fi

updated_count=0

for script in "$SCRIPTS_DIR"/*.sh; do
  [ -e "$script" ] || continue
  script_name=$(basename "$script" .sh)

  $DRY_RUN || chmod +x "$script"

  if $DRY_RUN; then
    log "INFO" "DRY-RUN: Would update $script_name"
  else
    cp "$script" "$INSTALL_DIR/$script_name"
    log "INFO" "Updated: $script_name"
  fi

  updated_count=$((updated_count + 1))
done

if [ "$updated_count" -eq 0 ]; then
  log "WARN" "No scripts updated."
else
  log "INFO" "Update complete. $updated_count script(s) processed."
  exit 0
fi
