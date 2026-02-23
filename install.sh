#!/system/bin/sh
# install.sh - Install Roblox optimizer as system commands
# Usage: su -c 'sh install.sh'
# After install: roblox-on / roblox-off from any terminal

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

msg() {
  printf "%b%s%b\n" "$1" "$2" "$NC"
}

# ============================================================
# Root check
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
  msg "$RED" "Error: Root required. Run: su -c 'sh install.sh'"
  exit 1
fi

# ============================================================
# Find script directory
# ============================================================
SCRIPT_DIR=$(dirname "$(readlink -f "$0")" 2>/dev/null)
if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ============================================================
# Install location
# ============================================================
INSTALL_DIR="/data/local/tmp/roblox-opt"
BIN_DIR="/system/bin"

msg "$CYAN" "=== Roblox Optimizer Installer ==="
printf "\n"

# ============================================================
# Copy scripts
# ============================================================
msg "$CYAN" "[1/4] Copying scripts to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

for f in roblox_mode.sh roblox_mode_off.sh roblox_watchdog.sh; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/$f"
    chmod 755 "$INSTALL_DIR/$f"
    msg "$GREEN" "  Copied: $f"
  else
    msg "$YELLOW" "  Not found: $f (skipping)"
  fi
done

# ============================================================
# Create wrapper commands
# ============================================================
msg "$CYAN" "[2/4] Creating commands..."

# Try /system/bin first (needs remount), fallback to /data/adb
MOUNTED=0
mount -o rw,remount /system 2>/dev/null && MOUNTED=1

if [ "$MOUNTED" -eq 0 ]; then
  # Try magisk's bin path
  if [ -d "/data/adb/modules" ]; then
    BIN_DIR="/data/adb/modules/roblox-opt/system/bin"
    mkdir -p "$BIN_DIR"
    # Create module descriptor for Magisk
    MODULE_DIR="/data/adb/modules/roblox-opt"
    echo "id=roblox-opt" > "$MODULE_DIR/module.prop"
    echo "name=Roblox Optimizer" >> "$MODULE_DIR/module.prop"
    echo "version=1.0" >> "$MODULE_DIR/module.prop"
    echo "versionCode=1" >> "$MODULE_DIR/module.prop"
    echo "author=roblox-android-opt" >> "$MODULE_DIR/module.prop"
    echo "description=roblox-on and roblox-off commands" >> "$MODULE_DIR/module.prop"
    msg "$CYAN" "  Using Magisk module path"
  else
    BIN_DIR="/data/local/tmp"
    msg "$YELLOW" "  /system not writable, using $BIN_DIR"
    msg "$YELLOW" "  You'll need to add /data/local/tmp to PATH"
  fi
fi

# roblox-on command
cat > "$BIN_DIR/roblox-on" << 'WRAPPER_ON'
#!/system/bin/sh
# roblox-on - Start Roblox optimization mode
# Usage: roblox-on [PLACE_ID] [PRIVATE_SERVER_CODE]
exec sh /data/local/tmp/roblox-opt/roblox_mode.sh "$@"
WRAPPER_ON
chmod 755 "$BIN_DIR/roblox-on"
msg "$GREEN" "  Created: roblox-on"

# roblox-off command
cat > "$BIN_DIR/roblox-off" << 'WRAPPER_OFF'
#!/system/bin/sh
# roblox-off - Restore normal settings
exec sh /data/local/tmp/roblox-opt/roblox_mode_off.sh "$@"
WRAPPER_OFF
chmod 755 "$BIN_DIR/roblox-off"
msg "$GREEN" "  Created: roblox-off"

# Remount /system read-only if we mounted it
if [ "$MOUNTED" -eq 1 ]; then
  mount -o ro,remount /system 2>/dev/null
fi

# ============================================================
# Install Termux shortcuts
# ============================================================
msg "$CYAN" "[3/4] Setting up Termux shortcuts..."

TERMUX_SHORTCUTS="$HOME/.shortcuts"
if [ -d "$TERMUX_SHORTCUTS" ] || [ -d "/data/data/com.termux/files/home/.shortcuts" ]; then
  TERMUX_SHORTCUTS="${TERMUX_SHORTCUTS:-/data/data/com.termux/files/home/.shortcuts}"
  mkdir -p "$TERMUX_SHORTCUTS"

  cat > "$TERMUX_SHORTCUTS/roblox_on.sh" << 'SHORTCUT_ON'
#!/data/data/com.termux/files/usr/bin/sh
su -c 'sh /data/local/tmp/roblox-opt/roblox_mode.sh'
SHORTCUT_ON
  chmod 755 "$TERMUX_SHORTCUTS/roblox_on.sh"

  cat > "$TERMUX_SHORTCUTS/roblox_off.sh" << 'SHORTCUT_OFF'
#!/data/data/com.termux/files/usr/bin/sh
su -c 'sh /data/local/tmp/roblox-opt/roblox_mode_off.sh'
SHORTCUT_OFF
  chmod 755 "$TERMUX_SHORTCUTS/roblox_off.sh"

  msg "$GREEN" "  Termux:Widget shortcuts installed"
else
  msg "$YELLOW" "  Termux shortcuts dir not found, skipping"
fi

# ============================================================
# Done
# ============================================================
msg "$CYAN" "[4/4] Verifying installation..."

OK=1
for cmd in roblox-on roblox-off; do
  if [ -f "$BIN_DIR/$cmd" ]; then
    msg "$GREEN" "  $cmd -> OK"
  else
    msg "$RED" "  $cmd -> MISSING"
    OK=0
  fi
done

printf "\n"
if [ "$OK" -eq 1 ]; then
  msg "$GREEN" "=== Installation complete ==="
  printf "\n"
  msg "$CYAN" "Usage:"
  msg "$CYAN" "  su -c 'roblox-on'                          # optimize + launch"
  msg "$CYAN" "  su -c 'roblox-on 123456789'                # join a game"
  msg "$CYAN" "  su -c 'roblox-on 123456789 servercode'     # join private server"
  msg "$CYAN" "  su -c 'roblox-off'                         # restore everything"
  printf "\n"
  msg "$CYAN" "Uninstall:"
  msg "$CYAN" "  su -c 'rm -rf /data/local/tmp/roblox-opt'"
  msg "$CYAN" "  su -c 'rm $BIN_DIR/roblox-on $BIN_DIR/roblox-off'"
else
  msg "$RED" "=== Installation had errors ==="
  msg "$YELLOW" "You can still run scripts directly:"
  msg "$YELLOW" "  su -c 'sh /data/local/tmp/roblox-opt/roblox_mode.sh'"
fi
