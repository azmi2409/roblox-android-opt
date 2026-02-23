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
  printf "%b%s%b\n" "$color" "$*" "$NC"
}

# ============================================================
# Root Access Gate
# ============================================================
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    print_status "$RED" "Error: Root access required. Run via su -c 'sh roblox_mode_off.sh'"
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
# VM Kernel Restore
# ============================================================
restore_vm_kernel() {
  echo 20 > /proc/sys/vm/dirty_ratio 2>/dev/null
  echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
  echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
  echo 11584 > /proc/sys/vm/min_free_kbytes 2>/dev/null
  print_status "$GREEN" "  VM kernel parameters restored to defaults"
}

# ============================================================
# Animation Restore
# ============================================================
restore_animations() {
  settings put global window_animation_scale 1.0 2>/dev/null
  settings put global transition_animation_scale 1.0 2>/dev/null
  settings put global animator_duration_scale 1.0 2>/dev/null
  print_status "$GREEN" "  Animations restored to defaults"
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
  setprop dalvik.vm.heapstartsize 8m
  setprop dalvik.vm.heapgrowthlimit 256m
  setprop dalvik.vm.heapsize 512m
  setprop dalvik.vm.heaptargetutilization 0.75
  setprop dalvik.vm.heapminfree 2m
  setprop dalvik.vm.heapmaxfree 8m
  print_status "$GREEN" "  Dalvik heap restored to defaults"
}

# ============================================================
# HW Overlays Restore
# ============================================================
restore_hw_overlays() {
  service call SurfaceFlinger 1008 i32 0 2>/dev/null
  print_status "$GREEN" "  Hardware overlays re-enabled"
}

# ============================================================
# Display Restore
# ============================================================
restore_display() {
  # Restore auto-rotation
  settings put system accelerometer_rotation 1 2>/dev/null
  print_status "$GREEN" "  Auto-rotation restored"

  # Resolution/density were not changed, no reset needed
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
printf "\n"
print_status "$CYAN" "=== ROBLOX MODE: OFF ==="
printf "\n"

print_status "$CYAN" "[1/10] Checking root access..."
check_root

print_status "$CYAN" "[2/10] Disabling ZRAM..."
disable_zram

print_status "$CYAN" "[3/10] Restoring swappiness..."
restore_swappiness

print_status "$CYAN" "[4/10] Restoring VM kernel parameters..."
restore_vm_kernel

print_status "$CYAN" "[5/10] Restoring animations..."
restore_animations

print_status "$CYAN" "[6/10] Restoring LMK minfree..."
restore_lmk

print_status "$CYAN" "[7/10] Restoring Dalvik heap..."
restore_dalvik

print_status "$CYAN" "[8/10] Restoring hardware overlays..."
restore_hw_overlays

print_status "$CYAN" "[9/10] Restoring display settings..."
restore_display

print_status "$CYAN" "[10/10] Re-enabling browsers..."
enable_browsers

printf "\n"
print_status "$GREEN" "=== All settings restored ==="
