#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="./scripts"
INSTALL_DIR="/usr/local/bin"
LOG_FILE="$HOME/check-installed.log"

log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

log "INFO" "Checking installed scripts..."
log "INFO" "Scripts source: $SCRIPTS_DIR"
log "INFO" "Install directory: $INSTALL_DIR"

if [ ! -d "$SCRIPTS_DIR" ]; then
  log "ERROR" "Scripts directory '$SCRIPTS_DIR' not found!"
  exit 1
fi

found_count=0
missing_count=0

for script in "$SCRIPTS_DIR"/*.sh; do
  [ -e "$script" ] || continue
  script_name=$(basename "$script" .sh)
  target="$INSTALL_DIR/$script_name"

  if [ -f "$target" ]; then
    log "OK" "Installed: $script_name ✅"
    found_count=$((found_count + 1))
  else
    log "WARN" "Missing: $script_name ❌"
    missing_count=$((missing_count + 1))
  fi
done

log "INFO" "Check complete. Found: $found_count, Missing: $missing_count"
