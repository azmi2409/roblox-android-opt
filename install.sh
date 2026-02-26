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
# Create wrapper commands in install dir
# ============================================================
msg "$CYAN" "[2/4] Creating commands..."

# Always create wrappers in INSTALL_DIR first
cat > "$INSTALL_DIR/roblox-on" << 'WRAPPER_ON'
#!/system/bin/sh
exec sh /data/local/tmp/roblox-opt/roblox_mode.sh "$@"
WRAPPER_ON
chmod 755 "$INSTALL_DIR/roblox-on"

cat > "$INSTALL_DIR/roblox-off" << 'WRAPPER_OFF'
#!/system/bin/sh
exec sh /data/local/tmp/roblox-opt/roblox_mode_off.sh "$@"
WRAPPER_OFF
chmod 755 "$INSTALL_DIR/roblox-off"

# Try to place commands in a directory that's already in PATH
BIN_DIR=""
MOUNTED=0

# Option 1: /system/bin (most reliable, needs remount)
mount -o rw,remount /system 2>/dev/null && MOUNTED=1
if [ "$MOUNTED" -eq 1 ]; then
  BIN_DIR="/system/bin"
  msg "$CYAN" "  Using /system/bin"
fi

# Option 2: /system/xbin (often writable on cloud phones)
if [ -z "$BIN_DIR" ] && [ -d "/system/xbin" ]; then
  mount -o rw,remount /system 2>/dev/null && MOUNTED=1
  if [ "$MOUNTED" -eq 1 ]; then
    BIN_DIR="/system/xbin"
    msg "$CYAN" "  Using /system/xbin"
  fi
fi

# Option 3: Magisk module (creates /system/bin overlay)
if [ -z "$BIN_DIR" ] && [ -d "/data/adb/modules" ]; then
  MODULE_DIR="/data/adb/modules/roblox-opt"
  BIN_DIR="$MODULE_DIR/system/bin"
  mkdir -p "$BIN_DIR"
  echo "id=roblox-opt" > "$MODULE_DIR/module.prop"
  echo "name=Roblox Optimizer" >> "$MODULE_DIR/module.prop"
  echo "version=1.0" >> "$MODULE_DIR/module.prop"
  echo "versionCode=1" >> "$MODULE_DIR/module.prop"
  echo "author=roblox-android-opt" >> "$MODULE_DIR/module.prop"
  echo "description=roblox-on and roblox-off commands" >> "$MODULE_DIR/module.prop"
  msg "$CYAN" "  Using Magisk module path (reboot needed)"
fi

# Option 4: /sbin (available on some rooted devices)
if [ -z "$BIN_DIR" ] && [ -d "/sbin" ] && [ -w "/sbin" ]; then
  BIN_DIR="/sbin"
  msg "$CYAN" "  Using /sbin"
fi

# Copy or symlink wrappers to BIN_DIR if we found one
if [ -n "$BIN_DIR" ] && [ "$BIN_DIR" != "$INSTALL_DIR" ]; then
  cp "$INSTALL_DIR/roblox-on" "$BIN_DIR/roblox-on"
  cp "$INSTALL_DIR/roblox-off" "$BIN_DIR/roblox-off"
  chmod 755 "$BIN_DIR/roblox-on" "$BIN_DIR/roblox-off"
  msg "$GREEN" "  Commands installed to $BIN_DIR"

  if [ "$MOUNTED" -eq 1 ]; then
    mount -o ro,remount /system 2>/dev/null
  fi
else
  BIN_DIR="$INSTALL_DIR"
  msg "$YELLOW" "  No system PATH dir writable"
  msg "$CYAN" "  Commands installed to $INSTALL_DIR"
fi

# Ensure /data/local/tmp/roblox-opt is in PATH for current and future shells
PATH_LINE='export PATH="$PATH:/data/local/tmp/roblox-opt"'
ADDED_PATH=0

# Termux user shell (~/.bashrc)
TERMUX_BASHRC="/data/data/com.termux/files/home/.bashrc"
if [ -f "$TERMUX_BASHRC" ] || [ -d "/data/data/com.termux/files/home" ]; then
  if ! grep -q "roblox-opt" "$TERMUX_BASHRC" 2>/dev/null; then
    printf '\n# Roblox optimizer commands\n%s\n' "$PATH_LINE" >> "$TERMUX_BASHRC" 2>/dev/null
    ADDED_PATH=1
    msg "$GREEN" "  Added to Termux ~/.bashrc"
  else
    msg "$GREEN" "  Already in Termux ~/.bashrc"
  fi
fi

# Termux .profile (some setups use this instead)
TERMUX_PROFILE="/data/data/com.termux/files/home/.profile"
if [ -f "$TERMUX_PROFILE" ]; then
  if ! grep -q "roblox-opt" "$TERMUX_PROFILE" 2>/dev/null; then
    printf '\n# Roblox optimizer commands\n%s\n' "$PATH_LINE" >> "$TERMUX_PROFILE" 2>/dev/null
    ADDED_PATH=1
    msg "$GREEN" "  Added to Termux ~/.profile"
  fi
fi

# Root shell profile (/data/local/tmp is root's typical home)
for profile in /etc/profile /system/etc/mkshrc; do
  if [ -f "$profile" ]; then
    if ! grep -q "roblox-opt" "$profile" 2>/dev/null; then
      mount -o rw,remount /system 2>/dev/null
      printf '\nexport PATH="$PATH:/data/local/tmp/roblox-opt"\n' >> "$profile" 2>/dev/null
      mount -o ro,remount /system 2>/dev/null
      ADDED_PATH=1
      msg "$GREEN" "  Added to $profile"
    fi
  fi
done

# Symlinks in /data/local/tmp as fallback (su -c often searches here)
ln -sf "$INSTALL_DIR/roblox-on" /data/local/tmp/roblox-on 2>/dev/null
ln -sf "$INSTALL_DIR/roblox-off" /data/local/tmp/roblox-off 2>/dev/null

if [ "$ADDED_PATH" -eq 0 ]; then
  msg "$YELLOW" "  Could not add to any profile, add manually:"
  msg "$YELLOW" "  echo '$PATH_LINE' >> ~/.bashrc"
fi

msg "$GREEN" "  Created: roblox-on"
msg "$GREEN" "  Created: roblox-off"

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
# Check if commands are accessible
for cmd in roblox-on roblox-off; do
  if [ -f "$BIN_DIR/$cmd" ] || [ -f "$INSTALL_DIR/$cmd" ]; then
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
  if [ "$BIN_DIR" = "$INSTALL_DIR" ]; then
    msg "$CYAN" "  su -c '/data/local/tmp/roblox-opt/roblox-on'                # optimize + launch"
    msg "$CYAN" "  su -c '/data/local/tmp/roblox-opt/roblox-on 123456789'      # join a game"
    msg "$CYAN" "  su -c '/data/local/tmp/roblox-opt/roblox-off'               # restore everything"
    printf "\n"
    msg "$CYAN" "Or add to PATH:"
    msg "$CYAN" "  export PATH=\"\$PATH:/data/local/tmp/roblox-opt\""
    msg "$CYAN" "Then use: su -c 'roblox-on'"
  else
    msg "$CYAN" "  su -c 'roblox-on'                          # optimize + launch"
    msg "$CYAN" "  su -c 'roblox-on 123456789'                # join a game"
    msg "$CYAN" "  su -c 'roblox-on 123456789 servercode'     # join private server"
    msg "$CYAN" "  su -c 'roblox-off'                         # restore everything"
  fi
  printf "\n"
  msg "$CYAN" "Uninstall:"
  msg "$CYAN" "  su -c 'rm -rf /data/local/tmp/roblox-opt'"
  if [ "$BIN_DIR" != "$INSTALL_DIR" ]; then
    msg "$CYAN" "  su -c 'rm $BIN_DIR/roblox-on $BIN_DIR/roblox-off'"
  fi
else
  msg "$RED" "=== Installation had errors ==="
  msg "$YELLOW" "You can still run scripts directly:"
  msg "$YELLOW" "  su -c 'sh /data/local/tmp/roblox-opt/roblox_mode.sh'"
fi
