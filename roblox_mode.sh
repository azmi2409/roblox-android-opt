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
  echo -e "${color}$*${NC}"
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
PROTECTED_PROCESSES="system_server|surfaceflinger|servicemanager|com.termux"

cleanup_background() {
  print_status "$CYAN" "Cleaning up background processes..."
  before_count=$(ps -A 2>/dev/null | wc -l)

  # Kill all background apps via activity manager
  am kill-all 2>/dev/null

  # Selective pkill for non-protected processes
  ps -A -o PID,NAME 2>/dev/null | while read pid name; do
    # Skip header line and empty lines
    [ -z "$pid" ] && continue
    echo "$pid" | grep -q '[^0-9]' && continue

    # Skip protected processes
    echo "$name" | grep -qE "$PROTECTED_PROCESSES" && continue

    kill -9 "$pid" 2>/dev/null
  done

  after_count=$(ps -A 2>/dev/null | wc -l)
  killed=$((before_count - after_count))
  [ "$killed" -lt 0 ] && killed=0
  print_status "$GREEN" "Killed $killed background processes."
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
  setprop dalvik.vm.heapgrowthlimit 256m
  setprop dalvik.vm.heapsize 384m
  print_status "$GREEN" "Dalvik heap: growthlimit=256m, heapsize=384m"
}

# ============================================================
# Graphics Memory Reduction
# ============================================================
tune_graphics() {
  print_status "$CYAN" "Tuning graphics settings..."
  service call SurfaceFlinger 1008 i32 1 2>/dev/null
  print_status "$GREEN" "Hardware overlays disabled"

  wm size reset 2>/dev/null
  print_status "$GREEN" "Display set to native resolution"
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
# Memory Trim Signal
# ============================================================
trim_memory() {
  ROBLOX_PIDS=$(pidof com.roblox.client 2>/dev/null)

  if [ -z "$ROBLOX_PIDS" ]; then
    print_status "$YELLOW" "No Roblox instances running, skipping trim."
    return
  fi

  for pid in $ROBLOX_PIDS; do
    am send-trim-memory "$pid" RUNNING_CRITICAL 2>/dev/null
  done
  print_status "$GREEN" "Sent TRIM_MEMORY_RUNNING_CRITICAL to Roblox instances"
}

# ============================================================
# Staggered Launch Guidance
# ============================================================
launch_guidance() {
  print_status "$CYAN" "=== Launch Guide ==="
  print_status "$CYAN" "Wait ~10 seconds between launching each Roblox instance."
  print_status "$CYAN" ""
  print_status "$CYAN" "Expected Memory Budget:"
  print_status "$CYAN" "  System overhead:    ~800MB"
  print_status "$CYAN" "  ZRAM expansion:     +700-900MB effective"
  print_status "$CYAN" "  Roblox x3:          ~1.2GB (300-400MB each)"
  print_status "$CYAN" "  GPU/compositor:     ~400MB"
  print_status "$CYAN" "  Estimated free RAM: ~1.3-1.6GB at idle"
}

# ============================================================
# Main Execution
# ============================================================
echo ""
print_status "$GREEN" "=== ROBLOX MODE: ON ==="
echo ""

print_status "$CYAN" "[1/10] Checking root access..."
check_root

print_status "$CYAN" "[2/10] Cleaning background processes..."
cleanup_background

print_status "$CYAN" "[3/10] Dropping filesystem caches..."
drop_caches

print_status "$CYAN" "[4/10] Configuring ZRAM..."
configure_zram

print_status "$CYAN" "[5/10] Tuning swappiness..."
tune_swappiness

print_status "$CYAN" "[6/10] Tuning Low Memory Killer..."
tune_lmk

print_status "$CYAN" "[7/10] Configuring Dalvik heap limits..."
tune_dalvik_heap

print_status "$CYAN" "[8/10] Tuning graphics settings..."
tune_graphics

print_status "$CYAN" "[9/10] Disabling browsers..."
disable_browsers

print_status "$CYAN" "[10/10] Trimming memory and preparing launch guide..."
trim_memory
launch_guidance

echo ""
print_status "$GREEN" "=== ROBLOX MODE READY ==="
