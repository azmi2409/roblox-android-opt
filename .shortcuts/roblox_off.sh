#!/data/data/com.termux/files/usr/bin/sh
# Termux:Widget launcher - Restore settings after Roblox mode
# Place this file in ~/.shortcuts/ and use Termux:Widget to add a home screen shortcut

tsu -c sh "$(dirname "$(readlink -f "$0")")/../roblox_mode_off.sh"
