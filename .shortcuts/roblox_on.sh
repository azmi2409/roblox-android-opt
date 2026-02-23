#!/data/data/com.termux/files/usr/bin/sh
# Termux:Widget launcher - Enable Roblox optimization mode
# Place this file in ~/.shortcuts/ and use Termux:Widget to add a home screen shortcut

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
su -c "sh '${SCRIPT_DIR}/../roblox_mode.sh'"
