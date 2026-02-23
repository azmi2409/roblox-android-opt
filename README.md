# Roblox Android Optimizer

Shell scripts that optimize a rooted Android 10 device with 4GB RAM for running **three simultaneous Roblox instances** in freeform mode. Kills background apps, configures ZRAM, tunes the low memory killer, limits Dalvik heap, disables browsers, and more — then cleanly reverts everything when you're done.

## Target Device

| Spec | Value |
|------|-------|
| OS | Android 10 |
| RAM | 4GB |
| Root | Required (Magisk, KernelSU, etc.) |
| Device | vsphone (or similar low-RAM Android) |
| Mode | Freeform windowing for multi-instance |

## Memory Budget

| Component | Allocation |
|-----------|-----------|
| System overhead | ~800 MB |
| ZRAM expansion | +700–900 MB effective |
| Roblox × 3 | ~1.2 GB (300–400 MB each) |
| GPU / compositor | ~400 MB |
| **Estimated free at idle** | **~1.3–1.6 GB** |

## Prerequisites

1. **Rooted device** — Magisk, KernelSU, or equivalent
2. **Termux** — Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) (the Play Store version is outdated)
3. **tsu** — Install inside Termux:
   ```bash
   pkg install tsu
   ```

## Installation

### Option A: Git clone

```bash
pkg install git
git clone https://github.com/azmi2409/roblox-android-opt.git
cd roblox-android-opt
chmod +x roblox_mode.sh roblox_mode_off.sh
```

### Option B: One-liner curl (no clone needed)

**Optimize:**

```bash
curl -sL https://raw.githubusercontent.com/azmi2409/roblox-android-opt/main/roblox_mode.sh | tsu -c sh
```

**Restore:**

```bash
curl -sL https://raw.githubusercontent.com/azmi2409/roblox-android-opt/main/roblox_mode_off.sh | tsu -c sh
```

> Replace `azmi2409` with your actual GitHub username.

## Usage

### Enable Roblox mode

```bash
tsu -c sh roblox_mode.sh
```

This runs all 10 optimization steps (see [What the scripts do](#what-the-scripts-do) below), then prints a launch guide. Wait ~10 seconds between launching each Roblox instance.

### Restore normal settings

```bash
tsu -c sh roblox_mode_off.sh
```

Reverts every change made by the optimization script in 7 steps.

## Optional Setup

### Termux:Widget (one-tap home screen shortcuts)

1. Install **Termux:Widget** from [F-Droid](https://f-droid.org/en/packages/com.termux.widget/)
2. Copy the widget launcher scripts:
   ```bash
   mkdir -p ~/.shortcuts
   cp .shortcuts/roblox_on.sh ~/.shortcuts/
   cp .shortcuts/roblox_off.sh ~/.shortcuts/
   chmod +x ~/.shortcuts/roblox_on.sh ~/.shortcuts/roblox_off.sh
   ```
3. Add a Termux:Widget to your home screen and select `roblox_on` or `roblox_off`

### Bashrc aliases

Add these to your `~/.bashrc` for quick access:

```bash
alias roblox-on='tsu -c sh ~/roblox-android-opt/roblox_mode.sh'
alias roblox-off='tsu -c sh ~/roblox-android-opt/roblox_mode_off.sh'
```

Then reload:

```bash
source ~/.bashrc
```

Now you can just type `roblox-on` or `roblox-off` in Termux.

## Troubleshooting

### Root access failure

```
Error: Root access required. Run via tsu or su.
```

- Make sure your device is rooted and Termux has superuser permission
- Run `tsu` by itself first to verify root works, then try again
- If using Magisk, check that Termux is in the superuser allow list

### ZRAM initialization failure

```
ZRAM initialization failed, continuing without ZRAM.
```

- The script continues without ZRAM — you'll have less effective RAM but everything else still works
- Some kernels don't expose `/sys/block/zram0`. Check with `ls /sys/block/zram*`
- Try rebooting and running the script again

### LMKD fallback

```
Using LMKD fallback via setprop
```

- This is normal on some Android 10 builds that use the userspace LMKD instead of the kernel LMK module
- The script automatically falls back to `setprop` — no action needed

### Browsers not re-enabling

If a browser stays disabled after running the restore script:

```bash
tsu -c pm enable --user 0 com.android.chrome
```

Replace `com.android.chrome` with the package name of the affected browser:
- Firefox: `org.mozilla.firefox`
- Samsung Internet: `com.sec.android.app.sbrowser`
- Edge: `com.microsoft.emmx`
- Opera: `com.opera.browser`
- Brave: `com.brave.browser`

## What the Scripts Do

### `roblox_mode.sh` — 10 optimization steps

1. **Root check** — Verifies UID 0; exits if not root
2. **Background cleanup** — Runs `am kill-all` and selectively kills non-essential processes (preserves system_server, surfaceflinger, servicemanager, Termux)
3. **Cache drop** — Syncs filesystem, drops page cache/dentries/inodes via `/proc/sys/vm/drop_caches`
4. **ZRAM setup** — Resets and configures a 2 GB ZRAM swap device for ~700–900 MB effective memory expansion
5. **Swappiness** — Sets kernel swappiness to 80 for aggressive ZRAM usage
6. **LMK tuning** — Writes aggressive minfree thresholds (`12288,16384,20480,24576,28672,32768` pages) to kill background apps earlier; falls back to LMKD `setprop` if needed
7. **Dalvik heap** — Limits per-app heap to `growthlimit=256m`, `heapsize=384m` to keep each Roblox instance within 300–400 MB
8. **Graphics** — Disables hardware overlays and resets display to native resolution to reduce compositor memory
9. **Browser disable** — Force-stops and disables Chrome, Firefox, Samsung Internet, Edge, Opera, and Brave to prevent accidental RAM usage
10. **Memory trim** — Sends `TRIM_MEMORY_RUNNING_CRITICAL` to any running Roblox instances, then prints a staggered launch guide

### `roblox_mode_off.sh` — 7 restore steps

1. **Root check** — Verifies UID 0; exits if not root
2. **ZRAM disable** — Runs `swapoff` on the ZRAM device
3. **Swappiness restore** — Resets to Android default (60)
4. **LMK restore** — Writes default minfree values (`18432,23040,27648,32256,36864,46080`)
5. **Dalvik heap restore** — Resets to Android 10 defaults (`growthlimit=256m`, `heapsize=512m`)
6. **HW overlays restore** — Re-enables hardware overlays
7. **Browser re-enable** — Re-enables all previously disabled browser packages

## License

MIT
