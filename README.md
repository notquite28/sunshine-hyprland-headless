# Sunshine Hyprland Headless

Production-ready automation for headless Sunshine + Moonlight streaming on Hyprland.

## Overview

This project enables streaming a Hyprland session via Sunshine/Moonlight without requiring physical monitors. It dynamically creates a virtual headless output that matches the Moonlight client's requested resolution and FPS, disables physical monitors during streaming, and restores the original monitor configuration when streaming ends.

## Architecture

```
Moonlight Client
    ↓ (requests resolution/FPS)
Sunshine Server
    ↓ (WLR capture)
Hyprland Compositor
    ↓ (manages outputs)
Virtual SUNSHINE Output
```

**No dummy plug required** - Hyprland's headless output support eliminates the need for HDMI/DisplayPort dummy plugs.

**Important**: Hyprland must already be running. This setup does not create a Wayland session from nothing.

## Requirements

- **Hyprland 0.55+** (with Lua-based runtime configuration)
- **Sunshine** (with WLR capture support)
- **Moonlight** (client)
- **jq** (JSON processor)
- **bash** (4.0+)

## Installation

### Quick Install

```bash
./install.sh
```

This copies scripts to `~/.local/bin/` and makes them executable.

### Manual Installation

```bash
# Copy scripts
cp scripts/sunshine-headless-start ~/.local/bin/
cp scripts/sunshine-headless-stop ~/.local/bin/
cp scripts/sunshine-headless-status ~/.local/bin/

# Make executable
chmod +x ~/.local/bin/sunshine-headless-start
chmod +x ~/.local/bin/sunshine-headless-stop
chmod +x ~/.local/bin/sunshine-headless-status
```

## Configuration

### Sunshine Settings

In Sunshine Web UI (`http://localhost:47990`):

1. **Capture Method**: `wlr`
2. **Display ID**: `SUNSHINE`

### Global Prep Commands

Configure Sunshine to run these scripts automatically:

**Do** (when stream starts):
```
$HOME/.local/bin/sunshine-headless-start
```

**Undo** (when stream ends):
```
$HOME/.local/bin/sunshine-headless-stop
```

**Note**: If Sunshine doesn't expand `$HOME`, get the absolute path:
```bash
printf '%s\n' "$HOME/.local/bin/sunshine-headless-start"
```

## Usage

### Manual Testing

Before wiring into Sunshine, test manually:

```bash
# Start headless streaming (simulates 2560x1440@120Hz client)
SUNSHINE_CLIENT_WIDTH=2560 \
SUNSHINE_CLIENT_HEIGHT=1440 \
SUNSHINE_CLIENT_FPS=120 \
~/.local/bin/sunshine-headless-start

# Verify setup
hyprctl monitors all

# Stop and restore
~/.local/bin/sunshine-headless-stop
```

### Check Status

```bash
~/.local/bin/sunshine-headless-status
```

## How It Works

### Start Script

1. Validates dependencies (hyprctl, jq, Hyprland running)
2. Acquires exclusive lock to prevent concurrent modifications
3. Detects active physical monitors via `hyprctl monitors all -j`
4. Saves monitor configuration to runtime state file
5. Creates `SUNSHINE` headless output (if not exists)
6. Configures SUNSHINE with client resolution/FPS
7. Verifies SUNSHINE output is active
8. Disables all physical monitors
9. Releases lock

### Stop Script

1. Validates dependencies
2. Acquires exclusive lock
3. Loads saved monitor configuration
4. Restores each physical monitor with exact settings (resolution, refresh rate, position, scale)
5. Verifies physical monitors are back
6. Removes SUNSHINE output
7. Cleans up runtime state
8. Releases lock

### Runtime State

State is stored in `${XDG_RUNTIME_DIR:-/tmp}/sunshine-hyprland-headless-${UID}/`:
- `monitors.json` - saved monitor configuration
- `lock` - exclusive lock file

## Troubleshooting

### "keyword can't work with non-legacy parsers. Use eval."

This project uses Hyprland 0.55+ Lua API (`hyprctl eval`). Ensure you're running Hyprland 0.55 or newer:

```bash
hyprctl version
```

### Sunshine shows "Display ID" instead of "Output Name"

In Sunshine, **Display ID = SUNSHINE** corresponds to the `output_name` setting. Set Display ID to `SUNSHINE`.

### Moonlight shows last frame/empty screen after manual stop

This is expected during manual testing. The stop script removes the SUNSHINE output, which is Sunshine's capture target. Normally the Undo command runs as the stream terminates.

### Physical monitors fail to return

The restoration explicitly sets `disabled = false`. If monitors still don't return:

1. Check if state file exists: `cat ${XDG_RUNTIME_DIR:-/tmp}/sunshine-hyprland-headless-${UID}/monitors.json`
2. Manually restore with `hyprctl eval`
3. Check Hyprland logs: `journalctl --user -u hyprland -f`

### Sunshine doesn't see virtual output

Verify SUNSHINE output exists:
```bash
hyprctl monitors all | grep SUNSHINE
```

Check Sunshine logs:
```bash
sunshine 2>&1 | tee /tmp/sunshine.log
grep -Ei 'prep|command|SUNSHINE|display|output|wlr|error|warn' /tmp/sunshine.log
```

Look for:
- `Name: SUNSHINE`
- `[wlgrab] Monitor ... is SUNSHINE`

## Safety

**Test the stop script before allowing the start script to disable all physical monitors.**

If something goes wrong:
1. SSH into the machine
2. Run `~/.local/bin/sunshine-headless-stop`
3. Or manually restore monitors via `hyprctl eval`

## Limitations

- Requires Hyprland 0.55+ with Lua monitor configuration support
- Requires working headless output support in your GPU driver
- Single-user per system (lock is per-UID)
- Does not handle multi-GPU setups explicitly

## License

MIT License - see LICENSE file for details.

## Contributing

Issues and PRs welcome. Please test on your setup before submitting changes.
