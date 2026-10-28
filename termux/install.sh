#!/usr/bin/env bash
# Run in Termux: downloads the Talkies APK your GitHub build made, installs it on the TV and makes it the home screen.
# Your own launcher stays installed; switch back any time with:  bash ~/talkies-tv/termux/switch-home.sh mine
set -euo pipefail
PKG=com.techpp.glass
DIR="${TALKIES_DIR:-$HOME/talkies-tv}"

command -v adb >/dev/null || { command -v pkg >/dev/null && pkg install -y android-tools; }
command -v adb >/dev/null || { echo "!! adb is missing (Termux: pkg install android-tools)"; exit 1; }

TVFILE="$HOME/.talkies_tv"
TV="${1:-}"
[ -z "$TV" ] && [ -f "$TVFILE" ] && TV="$(cat "$TVFILE")"
if [ -z "$TV" ]; then
  read -r -p "TV address, e.g. 192.168.1.20:5555: " TV
fi
echo "$TV" > "$TVFILE"
adb connect "$TV" >/dev/null || true

SDK="$(adb -s "$TV" shell -n getprop ro.build.version.sdk | tr -d '\r')"
if [ -n "$SDK" ] && [ "$SDK" -lt 30 ]; then
  echo "!! This TV runs Android API $SDK; Talkies needs API 30 (Android 11) or newer."
  exit 1
fi

ORIGIN="$(git -C "$DIR" remote get-url origin)"
SLUG="$(printf '%s' "$ORIGIN" | sed -E 's#^(https?://([^@/]*@)?github\.com/|git@github\.com:)##; s#\.git$##')"
URL="https://github.com/$SLUG/releases/download/latest/talkies.apk"
echo "== Downloading $URL"
curl -fL --retry 3 -o "$DIR/talkies.apk" "$URL" || {
  echo "!! Could not download it. Is the 'Build Talkies' run on GitHub finished and green, and the repo public?"
  exit 1
}

echo "== Installing on $TV"
if ! adb -s "$TV" install -r "$DIR/talkies.apk"; then
  echo "!! Install failed. If it says INSTALL_FAILED_UPDATE_INCOMPATIBLE, run:  adb -s $TV uninstall $PKG   and try again."
  exit 1
fi
adb -s "$TV" shell -n pm grant $PKG android.permission.ACCESS_FINE_LOCATION || true     # Wi-Fi name
adb -s "$TV" shell -n pm grant $PKG android.permission.READ_TV_LISTINGS || true         # Watch Next / Continue

# Optional keys saved next to the scripts (see the Talkies README: set-tmdb-key.sh / set-cricket-key.sh)
for k in tmdb_key.txt cricket_key.txt; do
  if [ -f "$DIR/$k" ]; then
    adb -s "$TV" shell -n mkdir -p /sdcard/Android/data/$PKG/files
    adb -s "$TV" push "$DIR/$k" /sdcard/Android/data/$PKG/files/$k >/dev/null
  fi
done

echo "== Making Talkies the home screen"
adb -s "$TV" shell -n cmd package set-home-activity --user 0 $PKG/.HomeActivity || true
adb -s "$TV" shell -n input keyevent KEYCODE_HOME

cat <<'MSG'

Installed. Two things to switch on, on the TV (Talkies asks for them):
  1. Settings > Device Preferences > Accessibility > Talkies   (keeps Home on Talkies, Turn off, remote keys)
  2. Settings > Apps > Special app access > Notification access > Talkies   (Continue watching, update bell)
Back to your own launcher any time:  bash ~/talkies-tv/termux/switch-home.sh mine
MSG
