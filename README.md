# Roblox Android Optimizer

Shell scripts that optimize a rooted Android device for running multiple simultaneous Roblox instances in freeform mode. Handles memory optimization, display configuration, auto-launch with game deep links, crash recovery via watchdog, and auto-installs Roblox if missing.

## Features

- 16-step memory and performance optimization
- Auto-detect and launch Roblox across all VSCloner user profiles
- Freeform windowing with auto-positioning (landscape, 360x640 per instance, side by side)
- Deep link support for auto-joining games and private servers
- Watchdog process that auto-restarts crashed instances
- Auto-download and install Roblox APK if not present
- One-command install with `roblox-on` / `roblox-off` shortcuts
- Cleanly reverts all changes when done

## Target Device

| Spec | Value |
|------|-------|
| OS | Android 10 |
| RAM | 4 GB |
| Root | Required (Magisk, KernelSU, etc.) |
| Device | vsphone KVIP (or similar) |
| Cloner | VSCloner (multi-user profiles) |
| Mode | Freeform windowing, landscape, 360x640 per instance side by side |

## Memory Budget

| Component | Allocation |
|-----------|-----------|
| System overhead | ~800 MB |
| ZRAM expansion | +700-900 MB effective |
| Roblox instances | ~300-400 MB each |
| GPU / compositor | ~400 MB |
| Estimated free at idle | ~1.3-1.6 GB |

## Prerequisites

1. Rooted device (Magisk, KernelSU, or equivalent)
2. [Termux](https://f-droid.org/en/packages/com.termux/) from F-Droid
3. [VSCloner](https://play.google.com/store/apps/details?id=com.vphone.clone) for multi-instance cloning
4. Verify root access:
   ```bash
   su -c 'id'
   ```

## Installation

### Quick Install

```bash
pkg install git
git clone https://github.com/azmi2409/roblox-android-opt.git
cd roblox-android-opt
su -c 'sh install.sh'
```

This copies scripts to `/data/local/tmp/roblox-opt/` and creates `roblox-on` / `roblox-off` commands. The installer tries `/system/bin` first, falls back to a Magisk module, or `/data/local/tmp`.

### One-liner Install (no git needed)

```bash
mkdir -p /data/local/tmp/roblox-setup && cd /data/local/tmp/roblox-setup && for f in roblox_mode.sh roblox_mode_off.sh roblox_watchdog.sh install.sh; do curl -sLO "https://raw.githubusercontent.com/azmi2409/roblox-android-opt/main/$f"; done && su -c 'sh install.sh'
```

## Usage

### Start Roblox mode

```bash
su -c 'roblox-on'
```

### Join a specific game

```bash
su -c 'roblox-on PLACE_ID'
```

### Join a private server

```bash
su -c 'roblox-on PLACE_ID PRIVATE_SERVER_CODE'
```

The Place ID is the number from the Roblox game URL (e.g. `https://www.roblox.com/games/123456789/GameName` -> `123456789`). The private server code is from the `privateServerLinkCode=` parameter in the invite link.

### Stop Roblox mode

```bash
su -c 'roblox-off'
```

Reverts all optimizations, stops the watchdog, restores display, re-enables browsers.

### Without installer (direct)

```bash
su -c 'sh roblox_mode.sh'                              # optimize + launch
su -c 'sh roblox_mode.sh 123456789'                    # join a game
su -c 'sh roblox_mode.sh 123456789 servercode'         # private server
su -c 'sh roblox_mode_off.sh'                          # restore
```

## How It Works

### `roblox_mode.sh` - 16 optimization steps

| Step | Action |
|------|--------|
| 1 | Root access check |
| 2 | Auto-download and install Roblox APK if missing, open VSCloner for cloning |
| 3 | Force-stop background packages (GMS, Play Store, Maps, YouTube, etc.) |
| 4 | Drop filesystem caches |
| 5 | Configure 2 GB ZRAM swap |
| 6 | Set swappiness to 80 |
| 7 | Tune VM kernel (dirty ratio, VFS cache pressure, min free KB) |
| 8 | Disable all animations |
| 9 | Tune Low Memory Killer thresholds |
| 10 | Limit Dalvik heap (256m growth, 384m max) |
| 11 | Disable hardware overlays |
| 12 | Configure freeform display (landscape, 360*N x 640, 120dpi) |
| 13 | Disable browsers (Chrome, Firefox, Edge, Opera, Brave, Samsung) |
| 14 | Auto-detect users with Roblox, launch in freeform, position windows |
| 15 | Send memory trim signal to all Roblox instances |
| 16 | Start watchdog for crash recovery |

### `roblox_mode_off.sh` - 11 restore steps

| Step | Action |
|------|--------|
| 1 | Stop watchdog |
| 2 | Root access check |
| 3 | Disable ZRAM |
| 4 | Restore swappiness to 60 |
| 5 | Restore VM kernel defaults |
| 6 | Restore animations |
| 7 | Restore LMK minfree defaults |
| 8 | Restore Dalvik heap defaults |
| 9 | Re-enable hardware overlays |
| 10 | Restore display (auto-rotation, native resolution) |
| 11 | Re-enable browsers |

### `roblox_watchdog.sh` - Crash recovery

Runs in the background, checks every 15 seconds if any Roblox instance has crashed. If one is down, it restarts it in freeform mode, repositions the window, and re-joins the same game/server if a deep link was used.

Logs to `/data/local/tmp/roblox_watchdog.log`.

### Multi-instance via VSCloner

VSCloner creates Android user profiles (DoppelgangerUsers) to run app clones. The script auto-detects all users with Roblox installed via `pm list users` + `pm list packages --user`, so you don't need to hardcode user IDs. If you add or remove clones, the script adapts automatically.

## File Structure

```
roblox_mode.sh        # Main optimization + launch script
roblox_mode_off.sh    # Restore all settings
roblox_watchdog.sh    # Background crash recovery
install.sh            # Installer (creates roblox-on/off commands)
.shortcuts/
  roblox_on.sh        # Termux:Widget shortcut
  roblox_off.sh       # Termux:Widget shortcut
```

## Troubleshooting

### Root access failure

Make sure Termux has superuser permission. Run `su -c 'id'` to verify. If using Magisk, check the superuser allow list.

### ZRAM initialization failure

The script continues without ZRAM. Some kernels don't expose `/sys/block/zram0`. Check with `ls /sys/block/zram*`.

### Browsers not re-enabling

Manually re-enable:
```bash
su -c 'pm enable --user 0 com.android.chrome'
```

### Watchdog log

```bash
cat /data/local/tmp/roblox_watchdog.log
```

### Manual watchdog stop

```bash
kill $(cat /data/local/tmp/roblox_watchdog.pid)
```

### Uninstall

```bash
su -c 'rm -rf /data/local/tmp/roblox-opt'
su -c 'rm /system/bin/roblox-on /system/bin/roblox-off'
```

If installed via Magisk module:
```bash
su -c 'rm -rf /data/adb/modules/roblox-opt'
```

## License

MIT