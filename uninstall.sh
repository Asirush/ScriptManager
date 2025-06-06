#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="./scripts"
INSTALL_DIR="/usr/local/bin"
LOG_FILE="$HOME/uninstall.log"
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

log "INFO" "Starting uninstallation..."
log "INFO" "Source: $SCRIPTS_DIR -> Target: $INSTALL_DIR"
$DRY_RUN && log "INFO" "Dry-run mode: No files will be deleted."

if [ ! -d "$SCRIPTS_DIR" ]; then
  log "ERROR" "Scripts directory not found!"
  exit 1
fi

uninstalled_count=0

for script in "$SCRIPTS_DIR"/*.sh; do
  [ -e "$script" ] || continue
  script_name=$(basename "$script" .sh)
  target="$INSTALL_DIR/$script_name"

  if [ -f "$target" ]; then
    if $DRY_RUN; then
      log "INFO" "DRY-RUN: Would remove $target"
    else
      rm -f "$target"
      log "INFO" "Removed: $target"
    fi
    uninstalled_count=$((uninstalled_count + 1))
  fi
done

if [ "$uninstalled_count" -eq 0 ]; then
  log "WARN" "No scripts were removed."
else
  log "INFO" "Uninstallation complete. $uninstalled_count script(s) processed."
fi
