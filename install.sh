#!/usr/bin/env bash
set -Eeuo pipefail

# One-liner installer for sunshine-hyprland-headless
# Usage: curl -fsSL https://raw.githubusercontent.com/quiet/sunshine-hyprland-headless/main/install.sh | bash

INSTALL_DIR="${HOME}/.local/bin"
SUNSHINE_CONF="${XDG_CONFIG_HOME:-${HOME}/.config}/sunshine/sunshine.conf"

log() { printf '[install] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# GitHub repository configuration
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

# Download a script
install_script() {
  local name="$1"
  local dst="${INSTALL_DIR}/${name}"
  local url="${BASE_URL}/scripts/${name}"
  
  log "Downloading $name"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dst" || die "Failed to download $name"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$dst" || die "Failed to download $name"
  else
    die "Neither curl nor wget found. Install one and retry."
  fi
  
  chmod +x "$dst" || die "Failed to make $name executable"
}

# Configure sunshine.conf
configure_sunshine() {
  local start_script="${INSTALL_DIR}/sunshine-headless-start"
  local stop_script="${INSTALL_DIR}/sunshine-headless-stop"
  
  log "Configuring $SUNSHINE_CONF"
  
  # Create config directory if needed
  mkdir -p "$(dirname "$SUNSHINE_CONF")" || die "Failed to create config directory"
  
  # Build prep command JSON
  local prep_cmd="[{\"do\":\"${start_script}\",\"undo\":\"${stop_script}\"}]"
  
  # Write config
  cat > "$SUNSHINE_CONF" <<EOF
capture = wlr
output_name = SUNSHINE
global_prep_cmd = ${prep_cmd}
EOF
  
  log "Sunshine configured"
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

# Configure sunshine
configure_sunshine

log "Installation complete!"
log
log "Restart Sunshine to apply changes:"
log "  systemctl --user restart sunshine"
log
log "Test manually:"
log "  SUNSHINE_CLIENT_WIDTH=2560 SUNSHINE_CLIENT_HEIGHT=1440 SUNSHINE_CLIENT_FPS=120 \\"
log "    $INSTALL_DIR/sunshine-headless-start"
log "  hyprctl monitors all"
log "  $INSTALL_DIR/sunshine-headless-stop"
