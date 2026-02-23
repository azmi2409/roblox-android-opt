#!/system/bin/sh
# roblox_mode_off.sh - Restore Android settings after Roblox optimization
# Target: Rooted Android 10, 4GB RAM

# ============================================================
# Color Output System
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
  color="$1"
  shift
  echo -e "${color}$*${NC}"
}

# ============================================================
# Root Access Gate
# ============================================================
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    print_status "$RED" "Error: Root access required. Run via tsu or su."
    exit 1
  fi
  print_status "$GREEN" "Root access confirmed."
}

# ============================================================
# ZRAM Disable
# ============================================================
disable_zram() {
  swapoff /dev/block/zram0 2>/dev/null
  if [ $? -eq 0 ]; then
    print_status "$GREEN" "  ZRAM disabled"
  else
    print_status "$YELLOW" "  ZRAM was not active, skipping"
  fi
}

# ============================================================
# Swappiness Restore
# ============================================================
restore_swappiness() {
  echo 60 > /proc/sys/vm/swappiness
  print_status "$GREEN" "  Swappiness restored to 60"
}

# ============================================================
# LMK Minfree Restore
# ============================================================
restore_lmk() {
  DEFAULT_MINFREE="18432,23040,27648,32256,36864,46080"
  if [ -f /sys/module/lowmemorykiller/parameters/minfree ]; then
    echo "$DEFAULT_MINFREE" > /sys/module/lowmemorykiller/parameters/minfree
    print_status "$GREEN" "  LMK minfree restored to defaults: $DEFAULT_MINFREE"
  else
    print_status "$YELLOW" "  LMK sysfs path not available, skipping minfree restore"
  fi
}

# ============================================================
# Dalvik Heap Restore
# ============================================================
restore_dalvik() {
  setprop dalvik.vm.heapgrowthlimit 256m
  setprop dalvik.vm.heapsize 512m
  print_status "$GREEN" "  Dalvik heap restored: growthlimit=256m, heapsize=512m"
}

# ============================================================
# HW Overlays Restore
# ============================================================
restore_hw_overlays() {
  service call SurfaceFlinger 1008 i32 0 2>/dev/null
  print_status "$GREEN" "  Hardware overlays re-enabled"
}

# ============================================================
# Browser Re-enabling
# ============================================================
BROWSER_PACKAGES="
com.android.chrome
org.mozilla.firefox
com.sec.android.app.sbrowser
com.microsoft.emmx
com.opera.browser
com.brave.browser
"

enable_browsers() {
  for pkg in $BROWSER_PACKAGES; do
    # Skip if package is not installed on device
    if ! pm list packages 2>/dev/null | grep -q "$pkg"; then
      continue
    fi

    pm enable --user 0 "$pkg" 2>/dev/null
    print_status "$GREEN" "  Re-enabled: $pkg"
  done
}

# ============================================================
# Main Execution
# ============================================================
echo ""
print_status "$CYAN" "=== ROBLOX MODE: OFF ==="
echo ""

print_status "$CYAN" "[1/7] Checking root access..."
check_root

print_status "$CYAN" "[2/7] Disabling ZRAM..."
disable_zram

print_status "$CYAN" "[3/7] Restoring swappiness..."
restore_swappiness

print_status "$CYAN" "[4/7] Restoring LMK minfree..."
restore_lmk

print_status "$CYAN" "[5/7] Restoring Dalvik heap..."
restore_dalvik

print_status "$CYAN" "[6/7] Restoring hardware overlays..."
restore_hw_overlays

print_status "$CYAN" "[7/7] Re-enabling browsers..."
enable_browsers

echo ""
print_status "$GREEN" "=== All settings restored ==="
