#!/usr/bin/env bash
set -Eeuo pipefail

# Installation script for sunshine-hyprland-headless
# Copies scripts to ~/.local/bin and makes them executable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

log() { printf '[install] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# Create install directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
  log "Creating $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR" || die "Failed to create $INSTALL_DIR"
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  log "WARNING: $INSTALL_DIR is not in your PATH"
  log "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  log "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo
fi

# Copy scripts
SCRIPTS=(
  "sunshine-headless-start"
  "sunshine-headless-stop"
  "sunshine-headless-status"
)

for script in "${SCRIPTS[@]}"; do
  src="${SCRIPT_DIR}/scripts/${script}"
  dst="${INSTALL_DIR}/${script}"
  
  if [[ ! -f "$src" ]]; then
    log "WARNING: $src not found, skipping"
    continue
  fi
  
  log "Installing $script -> $dst"
  cp "$src" "$dst" || die "Failed to copy $script"
  chmod +x "$dst" || die "Failed to make $script executable"
done

log "Installation complete!"
log
log "Next steps:"
log "  1. Configure Sunshine Web UI:"
log "     - Capture Method: wlr"
log "     - Display ID: SUNSHINE"
log "     - Global Prep Do: $INSTALL_DIR/sunshine-headless-start"
log "     - Global Prep Undo: $INSTALL_DIR/sunshine-headless-stop"
log
log "  2. Test manually:"
log "     SUNSHINE_CLIENT_WIDTH=2560 SUNSHINE_CLIENT_HEIGHT=1440 SUNSHINE_CLIENT_FPS=120 \\"
log "       $INSTALL_DIR/sunshine-headless-start"
log "     hyprctl monitors all"
log "     $INSTALL_DIR/sunshine-headless-stop"
