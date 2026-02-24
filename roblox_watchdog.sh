#!/system/bin/sh
# roblox_watchdog.sh - Monitor and auto-restart crashed Roblox instances
# Run in background: su -c 'sh roblox_watchdog.sh [PLACE_ID] [SERVER_CODE] &'
# Stop: kill $(cat /data/local/tmp/roblox_watchdog.pid)

# ============================================================
# Configuration (must match roblox_mode.sh)
# ============================================================
ROBLOX_PKG="com.roblox.client"
ROBLOX_ACTIVITY="com.roblox.client.startup.ActivitySplash"

DISPLAY_W=720
DISPLAY_H=1280

CHECK_INTERVAL=15  # seconds between checks
RESTART_DELAY=10   # seconds to wait after restarting before resize

PID_FILE="/data/local/tmp/roblox_watchdog.pid"
LOG_FILE="/data/local/tmp/roblox_watchdog.log"
USERS_FILE="/data/local/tmp/roblox_users.txt"

# ============================================================
# Game args (optional, passed from roblox_mode.sh or saved files)
# ============================================================
PLACE_ID="${1:-}"
PRIVATE_SERVER_CODE="${2:-}"

# Fallback: read from saved files if not passed as args
if [ -z "$PLACE_ID" ] && [ -f /data/local/tmp/roblox_place_id.txt ]; then
  PLACE_ID=$(cat /data/local/tmp/roblox_place_id.txt)
fi
if [ -z "$PRIVATE_SERVER_CODE" ] && [ -f /data/local/tmp/roblox_server_code.txt ]; then
  PRIVATE_SERVER_CODE=$(cat /data/local/tmp/roblox_server_code.txt)
fi

# ============================================================
# Logging
# ============================================================
log_msg() {
  timestamp=$(date '+%H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$1" >> "$LOG_FILE"
}

# ============================================================
# Save PID for clean shutdown
# ============================================================
echo $$ > "$PID_FILE"
log_msg "Watchdog started (PID $$)"
if [ -n "$PLACE_ID" ]; then
  log_msg "Game: $PLACE_ID (server: ${PRIVATE_SERVER_CODE:-public})"
fi

# ============================================================
# Cleanup on exit
# ============================================================
cleanup() {
  rm -f "$PID_FILE"
  log_msg "Watchdog stopped"
  exit 0
}
trap cleanup INT TERM

# ============================================================
# Load user list saved by roblox_mode.sh
# ============================================================
if [ -f "$USERS_FILE" ]; then
  ROBLOX_USERS=$(cat "$USERS_FILE")
else
  log_msg "No users file found at $USERS_FILE, exiting"
  rm -f "$PID_FILE"
  exit 1
fi

USER_COUNT=0
for u in $ROBLOX_USERS; do
  USER_COUNT=$((USER_COUNT + 1))
done

log_msg "Monitoring $USER_COUNT instances (users: $ROBLOX_USERS)"

# ============================================================
# Check if Roblox is running for a given user
# ============================================================
is_running() {
  user_id="$1"
  am stack list 2>/dev/null | grep "$ROBLOX_PKG" | grep -q "userId=$user_id"
}

# ============================================================
# Get task ID for a user's instance
# ============================================================
get_task_id() {
  user_id="$1"
  am stack list 2>/dev/null | grep "$ROBLOX_PKG" | grep "userId=$user_id" | head -1 | sed 's/.*taskId=\([0-9]*\).*/\1/'
}

# ============================================================
# Build launch command with optional deep link
# ============================================================
build_launch_cmd() {
  user_id="$1"
  base_cmd="am start --user $user_id --windowingMode 5"

  if [ -n "$PLACE_ID" ]; then
    uri="roblox://placeId=$PLACE_ID"
    if [ -n "$PRIVATE_SERVER_CODE" ]; then
      uri="${uri}&linkCode=$PRIVATE_SERVER_CODE"
    fi
    printf "%s" "$base_cmd -a android.intent.action.VIEW -d \"$uri\" -n $ROBLOX_PKG/$ROBLOX_ACTIVITY"
  else
    printf "%s" "$base_cmd -n $ROBLOX_PKG/$ROBLOX_ACTIVITY"
  fi
}

# ============================================================
# Restart and reposition a crashed instance
# ============================================================
restart_instance() {
  user_id="$1"
  top="$2"
  bottom="$3"
  instance_num="$4"

  log_msg "Instance $instance_num (user $user_id) crashed - restarting..."

  launch_cmd=$(build_launch_cmd "$user_id")
  eval "$launch_cmd" 2>/dev/null
  sleep "$RESTART_DELAY"

  task_id=$(get_task_id "$user_id")
  if [ -n "$task_id" ]; then
    am task resize "$task_id" 0 "$top" "$DISPLAY_W" "$bottom" 2>/dev/null
    log_msg "Instance $instance_num repositioned: 0,$top -> ${DISPLAY_W},$bottom"
  else
    log_msg "Instance $instance_num: could not find task after restart"
  fi
}

# ============================================================
# Main watchdog loop
# ============================================================
STATUS_BAR_H=36
USABLE_H=$((DISPLAY_H - STATUS_BAR_H))
ROW_H=$((USABLE_H / USER_COUNT))

while true; do
  instance=0
  for uid in $ROBLOX_USERS; do
    instance=$((instance + 1))
    TOP=$((STATUS_BAR_H + ROW_H * (instance - 1)))
    BOT=$((STATUS_BAR_H + ROW_H * instance))

    if [ "$instance" -eq "$USER_COUNT" ]; then
      BOT=$DISPLAY_H
    fi

    if ! is_running "$uid"; then
      restart_instance "$uid" "$TOP" "$BOT" "$instance"
    fi
  done

  sleep "$CHECK_INTERVAL"
done
