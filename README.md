# Sunshine Hyprland Headless

Stream your Hyprland desktop over Moonlight without any physical monitors plugged in. No HDMI dummy plugs, no hardcoded configs.

## What it does

Sunshine's WLR capture grabs whatever output Hyprland thinks is primary. When you're streaming remotely, you don't want your real monitors mirroring the stream — you want a virtual display that matches whatever resolution your Moonlight client asked for, with your physical monitors off.

These scripts handle that:

- **Stream starts** → saves your current monitor layout, creates a virtual `SUNSHINE` output at the client's resolution, turns off your physical monitors
- **Stream ends** → puts your physical monitors back exactly how they were, removes the virtual output

## How it fits together

```
Moonlight (client)
    │  requests resolution + FPS
    ▼
Sunshine (server)
    │  WLR capture
    ▼
Hyprland
    │  manages outputs
    ▼
Virtual SUNSHINE output
(whatever res/fps the client wants)
```

Why turn off physical monitors? Sunshine captures the primary display. If your real monitors are active, they fight for capture priority. Turning them off makes sure Sunshine grabs the virtual output.

No dummy plug needed — Hyprland can create headless outputs in software. Your GPU driver just needs to support it (most modern ones do).

**Note:** Hyprland needs to already be running. This doesn't create a Wayland session, it just manages outputs inside one.

## Requirements

- Hyprland 0.55+ (needs the Lua `hyprctl eval` API)
- Sunshine (WLR capture)
- Moonlight
- jq
- bash 4.0+

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/quiet/sunshine-hyprland-headless/main/install.sh | bash
```

Drops everything into `~/.local/bin/`.

## Setup

### Sunshine Web UI

Go to `http://localhost:47990`:

- **Capture Method:** `wlr`
- **Display ID:** `SUNSHINE`

### Global Prep Commands

In the Sunshine config, set:

- **Do:** `$HOME/.local/bin/sunshine-headless-start`
- **Undo:** `$HOME/.local/bin/sunshine-headless-stop`

If Sunshine doesn't expand `$HOME`, run this and paste the output:
```bash
printf '%s\n' "$HOME/.local/bin/sunshine-headless-start"
```

## Testing

Try it manually before hooking it up to Sunshine:

```bash
# Pretend a 2560x1440@120 client connected
SUNSHINE_CLIENT_WIDTH=2560 \
SUNSHINE_CLIENT_HEIGHT=1440 \
SUNSHINE_CLIENT_FPS=120 \
~/.local/bin/sunshine-headless-start

# Should see SUNSHINE output, physicals gone
hyprctl monitors all

# Put everything back
~/.local/bin/sunshine-headless-stop
```

Check what's going on at any time:
```bash
~/.local/bin/sunshine-headless-status
```

## How it actually works

### Start script

1. Checks that `hyprctl`, `jq`, and Hyprland are all available
2. Grabs an exclusive lock (so two simultaneous streams don't step on each other)
3. Runs `hyprctl monitors all -j` and pipes through `jq` to get every physical monitor's name, resolution, refresh rate, position, and scale
4. Saves that to a JSON file in `${XDG_RUNTIME_DIR:-/tmp}/sunshine-hyprland-headless-${UID}/`
5. Creates the `SUNSHINE` headless output if it doesn't already exist
6. Sets it to whatever resolution/FPS the Moonlight client requested (via `SUNSHINE_CLIENT_WIDTH`/`HEIGHT`/`FPS` env vars, defaults to 1920x1080@60)
7. **Verifies** the SUNSHINE output is actually active before touching physical monitors
8. Disables each physical monitor via `hyprctl eval` with the Lua API
9. Releases the lock

If anything fails partway through, a trap runs the stop script to put your monitors back.

### Stop script

1. Grabs the same lock
2. Reads the saved JSON
3. For each monitor, runs `hyprctl eval` with `disabled = false` and the exact saved mode/position/scale
4. Checks that physical monitors are back
5. Removes the SUNSHINE output
6. Cleans up the state files
7. Releases the lock

Safe to run multiple times — if there's no saved state, it just skips.

### State files

Everything lives in `${XDG_RUNTIME_DIR:-/tmp}/sunshine-hyprland-headless-${UID}/`:
- `monitors.json` — your physical monitor snapshot
- `lock` — flock lock file

Cleaned up automatically on stop.

## "Please don't brick my monitors"

**Test the stop script first.** Seriously, run `sunshine-headless-stop` a few times before letting the start script turn off all your physical displays. Make sure your monitors come back.

If something goes sideways:
1. SSH in
2. Run `~/.local/bin/sunshine-headless-stop`
3. Or manually: `hyprctl eval 'hl.monitor({output = "DP-1", disabled = false, mode = "2560x1440@165", position = "0x0", scale = 1})'`

## Troubleshooting

**"keyword can't work with non-legacy parsers. Use eval."**
You're on Hyprland < 0.55. This uses the Lua API. Upgrade.

**Sunshine shows "Display ID" not "Output Name"**
Same thing. Set Display ID to `SUNSHINE`.

**Moonlight shows a frozen screen after I manually ran stop**
That's because stop removes the SUNSHINE output, which is what Sunshine was capturing. During normal use, the undo command fires as the stream ends so you won't see this.

**Physical monitors didn't come back**
The script sets `disabled = false` explicitly — that's required, just setting a mode isn't enough. Check the saved state:
```bash
cat "${XDG_RUNTIME_DIR:-/tmp}/sunshine-hyprland-headless-${UID}/monitors.json"
```
And check Hyprland logs: `journalctl --user -u hyprland -f`

**Sunshine doesn't see the virtual output**
```bash
hyprctl monitors all | grep SUNSHINE
sunshine 2>&1 | tee /tmp/sunshine.log
grep -Ei 'SUNSHINE|wlr|display|output' /tmp/sunshine.log
```
You're looking for `Name: SUNSHINE` and `[wlgrab] Monitor ... is SUNSHINE`.

## Limitations

- Hyprland 0.55+ only
- GPU driver needs to support headless outputs
- One user per machine (lock is per-UID)
- Doesn't handle multi-GPU setups

## License

MIT
