#!/usr/bin/env bash
set -Eeuo pipefail

# Installation script for sunshine-hyprland-headless
# Supports both local installation and curl | bash one-liner.
#
# Usage:
#   Local (from git clone): ./install.sh
#   Remote (one-liner): curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash

INSTALL_DIR="${HOME}/.local/bin"

log() { printf '[install] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# Detect if running from local clone or curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
LOCAL_MODE=false

if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/scripts" ]]; then
  LOCAL_MODE=true
  log "Detected local installation from $SCRIPT_DIR"
else
  log "Remote installation mode - fetching from GitHub"
fi

# GitHub repository configuration
# Override with environment variables if needed:
#   GITHUB_USER=myuser GITHUB_REPO=myrepo GITHUB_BRANCH=dev curl ... | bash
GITHUB_USER="${GITHUB_USER:-quiet}"
GITHUB_REPO="${GITHUB_REPO:-sunshine-hyprland-headless}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

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

# Download or copy a script
install_script() {
  local name="$1"
  local dst="${INSTALL_DIR}/${name}"
  
  if [[ "$LOCAL_MODE" == true ]]; then
    local src="${SCRIPT_DIR}/scripts/${name}"
    if [[ ! -f "$src" ]]; then
      log "WARNING: $src not found, skipping"
      return 0
    fi
    log "Installing $name (local)"
    cp "$src" "$dst" || die "Failed to copy $name"
  else
    local url="${BASE_URL}/scripts/${name}"
    log "Downloading $name from $url"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$url" -o "$dst" || die "Failed to download $name"
    elif command -v wget >/dev/null 2>&1; then
      wget -q "$url" -O "$dst" || die "Failed to download $name"
    else
      die "Neither curl nor wget found. Install one and retry."
    fi
  fi
  
  chmod +x "$dst" || die "Failed to make $name executable"
}

# Install scripts
SCRIPTS=(
  "sunshine-headless-start"
  "sunshine-headless-stop"
  "sunshine-headless-status"
)

for script in "${SCRIPTS[@]}"; do
  install_script "$script"
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
log
if [[ "$LOCAL_MODE" == false ]]; then
  log "One-liner for future use:"
  log "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash"
fi
