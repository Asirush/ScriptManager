#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="./scripts"
INSTALL_DIR="/usr/local/bin"
LOG_FILE="$HOME/install.log"
DRY_RUN=false

# Check for --dry-run
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

log "INFO" "Starting installation..."
log "INFO" "Source: $SCRIPTS_DIR -> Destination: $INSTALL_DIR"
$DRY_RUN && log "INFO" "Dry-run mode: No changes will be made."

if [ ! -d "$SCRIPTS_DIR" ]; then
  log "ERROR" "Scripts directory not found!"
  exit 1
fi

installed_count=0

for script in "$SCRIPTS_DIR"/*.sh; do
  [ -e "$script" ] || continue
  script_name=$(basename "$script" .sh)

  $DRY_RUN || chmod +x "$script"

  if $DRY_RUN; then
    log "INFO" "DRY-RUN: Would install $script_name -> $INSTALL_DIR/$script_name"
  else
    cp "$script" "$INSTALL_DIR/$script_name"
    log "INFO" "Installed: $script_name -> $INSTALL_DIR/$script_name"
  fi

  installed_count=$((installed_count + 1))
done

if [ "$installed_count" -eq 0 ]; then
  log "WARN" "No scripts found to install." && exit 1
else
  log "INFO" "Installation complete. $installed_count script(s) processed."
  exit 0
fi
