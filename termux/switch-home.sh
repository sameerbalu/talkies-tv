#!/usr/bin/env bash
# Switch which launcher answers the Home button. Both stay installed.
#   bash switch-home.sh mine      # your tv-vibehack launcher
#   bash switch-home.sh talkies   # Talkies
set -euo pipefail
case "${1:-}" in
  mine)    C=com.gathin.tvhome/.MainActivity ;;
  talkies) C=com.techpp.glass/.HomeActivity ;;
  *) echo "usage: bash switch-home.sh mine|talkies [tv-ip:port]"; exit 1 ;;
esac
TVFILE="$HOME/.talkies_tv"
TV="${2:-}"
[ -z "$TV" ] && [ -f "$TVFILE" ] && TV="$(cat "$TVFILE")"
[ -z "$TV" ] && { echo "!! No TV address. Pass it as the second argument."; exit 1; }
adb connect "$TV" >/dev/null || true
adb -s "$TV" shell -n cmd package set-home-activity --user 0 "$C"
adb -s "$TV" shell -n input keyevent KEYCODE_HOME
echo "Home is now: $C"
