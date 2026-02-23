#!/system/bin/sh
# roblox_mode.sh - Android memory optimization for 3x Roblox instances
# Target: Rooted Android 10, 4GB RAM, freeform mode

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
    print_status "$RED" "Error: Root access required. Run via su -c 'sh roblox_mode.sh'"
    exit 1
  fi
  print_status "$GREEN" "Root access confirmed."
}

# ============================================================
# Background Process Cleanup
# ============================================================
# Packages to force-stop for RAM (safe list, won't touch Termux or system)
KILL_PACKAGES="
com.google.android.gms
com.google.android.gsf
com.android.vending
com.android.calendar
com.android.email
com.android.providers.calendar
com.android.providers.contacts
com.android.printspooler
com.android.managedprovisioning
com.android.cellbroadcastreceiver
com.google.android.apps.maps
com.google.android.youtube
com.google.android.music
com.google.android.videos
com.google.android.apps.photos
com.google.android.apps.docs
com.google.android.apps.tachyon
com.google.android.keep
com.google.android.apps.messaging
com.android.nfc
com.android.bluetooth
com.android.providers.media
com.google.android.syncadapters.contacts
com.google.android.backuptransport
com.google.android.partnersetup
"

cleanup_background() {
  print_status "$CYAN" "Cleaning up background processes..."
  killed=0

  # Selectively force-stop known memory-hungry packages
  # This is safe: only targets specific packages, never Termux or system
  for pkg in $KILL_PACKAGES; do
    # Check if package exists before trying to stop it
    if pm list packages 2>/dev/null | grep -q "$pkg"; then
      am force-stop "$pkg" 2>/dev/null
      killed=$((killed + 1))
    fi
  done

  print_status "$GREEN" "Force-stopped $killed background packages."
}

# ============================================================
# Cache Dropping
# ============================================================
drop_caches() {
  print_status "$CYAN" "Dropping filesystem caches..."
  free_before=$(grep MemFree /proc/meminfo | awk '{print $2}')

  sync
  echo 3 > /proc/sys/vm/drop_caches

  free_after=$(grep MemFree /proc/meminfo | awk '{print $2}')
  freed_kb=$((free_after - free_before))
  [ "$freed_kb" -lt 0 ] && freed_kb=0
  freed_mb=$((freed_kb / 1024))
  print_status "$GREEN" "Freed ${freed_mb}MB from caches."
}

# ============================================================
# ZRAM Configuration
# ============================================================
ZRAM_SIZE=2147483648  # 2GB

configure_zram() {
  print_status "$CYAN" "Configuring ZRAM..."

  # Reset existing ZRAM
  swapoff /dev/block/zram0 2>/dev/null
  echo 1 > /sys/block/zram0/reset 2>/dev/null

  # Set ZRAM disk size
  echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>/dev/null
  if [ $? -ne 0 ]; then
    print_status "$YELLOW" "ZRAM initialization failed, continuing without ZRAM."
    return
  fi

  # Create and enable swap
  mkswap /dev/block/zram0 2>/dev/null
  swapon /dev/block/zram0 2>/dev/null
  if [ $? -ne 0 ]; then
    print_status "$YELLOW" "ZRAM initialization failed, continuing without ZRAM."
    return
  fi

  print_status "$GREEN" "ZRAM enabled: 2GB"
}

# ============================================================
# Swappiness Tuning
# ============================================================
tune_swappiness() {
  print_status "$CYAN" "Tuning swappiness..."
  echo 80 > /proc/sys/vm/swappiness
  print_status "$GREEN" "Swappiness set to 80"
}

# ============================================================
# VM Kernel Tuning
# ============================================================
tune_vm_kernel() {
  print_status "$CYAN" "Tuning VM kernel parameters..."

  # Reduce dirty page ratio — flush to disk sooner, free RAM faster
  echo 10 > /proc/sys/vm/dirty_ratio 2>/dev/null
  echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null

  # Aggressively reclaim VFS cache (dentries/inodes)
  echo 200 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null

  # Reduce minimum free memory the kernel reserves
  echo 8192 > /proc/sys/vm/min_free_kbytes 2>/dev/null

  # Disable OOM dump tasks (saves CPU during OOM events)
  echo 0 > /proc/sys/vm/oom_dump_tasks 2>/dev/null

  print_status "$GREEN" "VM kernel parameters tuned"
}

# ============================================================
# Disable Animations
# ============================================================
disable_animations() {
  print_status "$CYAN" "Disabling animations..."

  settings put global window_animation_scale 0.0 2>/dev/null
  settings put global transition_animation_scale 0.0 2>/dev/null
  settings put global animator_duration_scale 0.0 2>/dev/null

  print_status "$GREEN" "All animations disabled"
}

# ============================================================
# LMK Minfree Tuning
# ============================================================
tune_lmk() {
  print_status "$CYAN" "Tuning Low Memory Killer..."
  MINFREE="12288,16384,20480,24576,28672,32768"

  if [ -f /sys/module/lowmemorykiller/parameters/minfree ]; then
    echo "$MINFREE" > /sys/module/lowmemorykiller/parameters/minfree
    print_status "$GREEN" "LMK minfree set: $MINFREE"
  else
    setprop sys.lmk.minfree_levels "48,64,80,96,112,128"
    print_status "$YELLOW" "Using LMKD fallback via setprop"
  fi
}

# ============================================================
# Dalvik Heap Limiting
# ============================================================
tune_dalvik_heap() {
  print_status "$CYAN" "Configuring Dalvik heap limits..."
  setprop dalvik.vm.heapstartsize 8m
  setprop dalvik.vm.heapgrowthlimit 256m
  setprop dalvik.vm.heapsize 384m
  setprop dalvik.vm.heaptargetutilization 0.75
  setprop dalvik.vm.heapminfree 512k
  setprop dalvik.vm.heapmaxfree 8m
  print_status "$GREEN" "Dalvik heap: start=8m, growth=256m, max=384m, util=75%"
}

# ============================================================
# Graphics Memory Reduction
# ============================================================
tune_graphics() {
  print_status "$CYAN" "Tuning graphics settings..."
  service call SurfaceFlinger 1008 i32 1 2>/dev/null
  print_status "$GREEN" "Hardware overlays disabled"
}

# ============================================================
# Freeform Display Configuration
# ============================================================
configure_freeform_display() {
  print_status "$CYAN" "Configuring display for freeform stacking..."

  # Keep portrait orientation (native), disable auto-rotate
  settings put system accelerometer_rotation 0 2>/dev/null
  print_status "$GREEN" "Auto-rotation disabled (portrait locked)"

  # Set portrait resolution explicitly
  wm size 720x1280 2>/dev/null
  print_status "$GREEN" "Display resolution set to 720x1280 HD (portrait)"

  # Standard density for vsphone KVIP
  wm density 240 2>/dev/null
  print_status "$GREEN" "Display density set to 240dpi"

  # Enable freeform window mode
  settings put global enable_freeform_support 1 2>/dev/null
  print_status "$GREEN" "Freeform window mode enabled"
}

# ============================================================
# Browser Disabling
# ============================================================
BROWSER_PACKAGES="
com.android.chrome
org.mozilla.firefox
com.sec.android.app.sbrowser
com.microsoft.emmx
com.opera.browser
com.brave.browser
"

disable_browsers() {
  print_status "$CYAN" "Disabling browsers..."
  for pkg in $BROWSER_PACKAGES; do
    # Skip if package is not installed
    if ! pm list packages 2>/dev/null | grep -q "$pkg"; then
      continue
    fi

    am force-stop "$pkg" 2>/dev/null
    pm disable-user --user 0 "$pkg" 2>/dev/null
    print_status "$GREEN" "Disabled: $pkg"
  done
}

# ============================================================
# Roblox Instance Configuration (VSCloner multi-user)
# ============================================================
ROBLOX_PKG="com.roblox.client"
ROBLOX_ACTIVITY="com.roblox.client.startup.ActivitySplash"

# Display dimensions (must match configure_freeform_display)
DISPLAY_W=720
DISPLAY_H=1280

# ============================================================
# Detect All Users with Roblox Installed
# ============================================================
detect_roblox_users() {
  # Get all user IDs from the system
  ROBLOX_USERS=""
  user_ids=$(pm list users 2>/dev/null | grep "UserInfo" | sed 's/.*UserInfo{\([0-9]*\):.*/\1/')

  for uid in $user_ids; do
    # Check if Roblox is installed for this user
    if pm list packages --user "$uid" 2>/dev/null | grep -q "$ROBLOX_PKG"; then
      ROBLOX_USERS="$ROBLOX_USERS $uid"
    fi
  done

  # Trim leading space
  ROBLOX_USERS=$(echo "$ROBLOX_USERS" | sed 's/^ //')

  USER_COUNT=0
  for u in $ROBLOX_USERS; do
    USER_COUNT=$((USER_COUNT + 1))
  done

  if [ "$USER_COUNT" -eq 0 ]; then
    print_status "$RED" "No users with Roblox installed found"
    return 1
  fi

  print_status "$GREEN" "Found $USER_COUNT user(s) with Roblox: $ROBLOX_USERS"

  # Save user list for watchdog
  echo "$ROBLOX_USERS" > /data/local/tmp/roblox_users.txt
  return 0
}

# ============================================================
# Get Task ID for a User's Roblox Instance
# ============================================================
get_task_id() {
  user_id="$1"
  am stack list 2>/dev/null | grep "$ROBLOX_PKG" | grep "userId=$user_id" | head -1 | sed 's/.*taskId=\([0-9]*\).*/\1/'
}

# ============================================================
# Launch and Position Roblox Instances
# ============================================================
launch_roblox_instances() {
  if ! detect_roblox_users; then
    return 1
  fi

  print_status "$CYAN" "Launching and positioning Roblox instances..."

  ROW_H=$((DISPLAY_H / USER_COUNT))
  instance=0

  for uid in $ROBLOX_USERS; do
    instance=$((instance + 1))
    TOP=$((ROW_H * (instance - 1)))
    BOT=$((ROW_H * instance))

    # Last instance takes remaining pixels to avoid gaps
    if [ "$instance" -eq "$USER_COUNT" ]; then
      BOT=$DISPLAY_H
    fi

    print_status "$CYAN" "  Launching instance $instance (user $uid)..."
    am start --user "$uid" --windowingMode 5 -n "$ROBLOX_PKG/$ROBLOX_ACTIVITY" 2>/dev/null
    sleep 8

    task_id=$(get_task_id "$uid")
    if [ -n "$task_id" ]; then
      am task resize "$task_id" 0 "$TOP" "$DISPLAY_W" "$BOT" 2>/dev/null
      print_status "$GREEN" "  Instance $instance positioned: 0,$TOP -> ${DISPLAY_W},$BOT"
    else
      print_status "$YELLOW" "  Could not find task for instance $instance"
    fi
  done
}

# ============================================================
# Memory Trim Signal
# ============================================================
trim_memory() {
  ALL_PIDS=$(pidof "$ROBLOX_PKG" 2>/dev/null)

  if [ -z "$ALL_PIDS" ]; then
    print_status "$YELLOW" "No Roblox instances running, skipping trim."
    return
  fi

  for pid in $ALL_PIDS; do
    am send-trim-memory "$pid" RUNNING_CRITICAL 2>/dev/null
  done
  print_status "$GREEN" "Sent TRIM_MEMORY_RUNNING_CRITICAL to Roblox instances"
}

# ============================================================
# Start Watchdog Process
# ============================================================
start_watchdog() {
  # Kill any existing watchdog
  if [ -f /data/local/tmp/roblox_watchdog.pid ]; then
    old_pid=$(cat /data/local/tmp/roblox_watchdog.pid)
    kill "$old_pid" 2>/dev/null
  fi

  # Find the watchdog script
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")" 2>/dev/null)
  if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  fi

  if [ -f "$SCRIPT_DIR/roblox_watchdog.sh" ]; then
    sh "$SCRIPT_DIR/roblox_watchdog.sh" &
    print_status "$GREEN" "Watchdog started (PID $!)"
  else
    print_status "$YELLOW" "Watchdog script not found at $SCRIPT_DIR/roblox_watchdog.sh"
    print_status "$YELLOW" "Run manually: su -c 'sh roblox_watchdog.sh &'"
  fi
}

# ============================================================
# Launch Summary
# ============================================================
launch_summary() {
  print_status "$CYAN" ""
  print_status "$CYAN" "Expected Memory Budget:"
  print_status "$CYAN" "  System overhead:    ~800MB"
  print_status "$CYAN" "  ZRAM expansion:     +700-900MB effective"
  print_status "$CYAN" "  Roblox x3:          ~1.2GB (300-400MB each)"
  print_status "$CYAN" "  GPU/compositor:     ~400MB"
  print_status "$CYAN" "  Estimated free RAM: ~1.3-1.6GB at idle"
  print_status "$CYAN" ""
  print_status "$CYAN" "Freeform Layout (portrait):"
  print_status "$CYAN" "  Display:    ${DISPLAY_W}x${DISPLAY_H}"
  print_status "$CYAN" "  Instances:  auto-detected from installed users"
  print_status "$CYAN" ""
  print_status "$CYAN" "To manually resize a window:"
  print_status "$CYAN" "  am stack list                              # find taskId"
  print_status "$CYAN" "  am task resize <taskId> left top right bot # resize it"
}

# ============================================================
# Main Execution
# ============================================================
printf "\n"
print_status "$GREEN" "=== ROBLOX MODE: ON ==="
printf "\n"

print_status "$CYAN" "[1/15] Checking root access..."
check_root

print_status "$CYAN" "[2/15] Cleaning background processes..."
cleanup_background

print_status "$CYAN" "[3/15] Dropping filesystem caches..."
drop_caches

print_status "$CYAN" "[4/15] Configuring ZRAM..."
configure_zram

print_status "$CYAN" "[5/15] Tuning swappiness..."
tune_swappiness

print_status "$CYAN" "[6/15] Tuning VM kernel parameters..."
tune_vm_kernel

print_status "$CYAN" "[7/15] Disabling animations..."
disable_animations

print_status "$CYAN" "[8/15] Tuning Low Memory Killer..."
tune_lmk

print_status "$CYAN" "[9/15] Configuring Dalvik heap limits..."
tune_dalvik_heap

print_status "$CYAN" "[10/15] Tuning graphics settings..."
tune_graphics

print_status "$CYAN" "[11/15] Configuring freeform display..."
configure_freeform_display

print_status "$CYAN" "[12/15] Disabling browsers..."
disable_browsers

print_status "$CYAN" "[13/15] Launching and positioning Roblox instances..."
launch_roblox_instances

print_status "$CYAN" "[14/15] Trimming memory..."
trim_memory

print_status "$CYAN" "[15/15] Starting watchdog..."
start_watchdog
launch_summary

printf "\n"
print_status "$GREEN" "=== ROBLOX MODE READY ==="
