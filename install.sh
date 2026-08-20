#!/usr/bin/env bash
set -Eeuo pipefail

# One-liner installer for sunshine-hyprland-headless
# Usage: curl -fsSL https://raw.githubusercontent.com/notquite28/sunshine-hyprland-headless/main/install.sh | bash

INSTALL_DIR="${HOME}/.local/scripts"
SUNSHINE_CONF="${XDG_CONFIG_HOME:-${HOME}/.config}/sunshine/sunshine.conf"

log() { printf '[install] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# GitHub repository configuration
GITHUB_USER="${GITHUB_USER:-notquite28}"
GITHUB_REPO="${GITHUB_REPO:-sunshine-hyprland-headless}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Create install directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
  log "Creating $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR" || die "Failed to create $INSTALL_DIR"
fi

# Check if ~/.local/scripts is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  log "WARNING: $INSTALL_DIR is not in your PATH"
  log "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  log "  export PATH=\"\$HOME/.local/scripts:\$PATH\""
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
  
  # Backup existing config
  if [[ -f "$SUNSHINE_CONF" ]]; then
    cp "$SUNSHINE_CONF" "${SUNSHINE_CONF}.bak"
    log "Backed up existing config to ${SUNSHINE_CONF}.bak"
  fi
  
  # If config doesn't exist, create it with our settings
  if [[ ! -f "$SUNSHINE_CONF" ]]; then
    local prep_cmd="[{\"do\":\"${start_script}\",\"undo\":\"${stop_script}\"}]"
    cat > "$SUNSHINE_CONF" <<EOF
capture = wlr
output_name = SUNSHINE
global_prep_cmd = ${prep_cmd}
EOF
    log "Created new sunshine.conf"
    return 0
  fi
  
  # Config exists - update only our keys, preserve everything else
  local tmp_file="${SUNSHINE_CONF}.tmp"
  local keys_updated=()
  
  # Update capture method
  if grep -q "^capture *=" "$SUNSHINE_CONF"; then
    sed "s|^capture *=.*|capture = wlr|" "$SUNSHINE_CONF" > "$tmp_file"
    mv "$tmp_file" "$SUNSHINE_CONF"
    keys_updated+=("capture")
  else
    echo "capture = wlr" >> "$SUNSHINE_CONF"
    keys_updated+=("capture")
  fi
  
  # Update output name
  if grep -q "^output_name *=" "$SUNSHINE_CONF"; then
    sed "s|^output_name *=.*|output_name = SUNSHINE|" "$SUNSHINE_CONF" > "$tmp_file"
    mv "$tmp_file" "$SUNSHINE_CONF"
    keys_updated+=("output_name")
  else
    echo "output_name = SUNSHINE" >> "$SUNSHINE_CONF"
    keys_updated+=("output_name")
  fi
  
  # Handle global_prep_cmd - merge if exists, don't overwrite
  if grep -q "^global_prep_cmd *=" "$SUNSHINE_CONF"; then
    log "global_prep_cmd already exists in config"
    log "Please manually add this entry to your global_prep_cmd array:"
    log "  {\"do\":\"${start_script}\",\"undo\":\"${stop_script}\"}"
    log "Skipping global_prep_cmd update to preserve existing commands"
  else
    local prep_cmd="[{\"do\":\"${start_script}\",\"undo\":\"${stop_script}\"}]"
    echo "global_prep_cmd = ${prep_cmd}" >> "$SUNSHINE_CONF"
    keys_updated+=("global_prep_cmd")
  fi
  
  log "Updated sunshine.conf: ${keys_updated[*]}"
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
