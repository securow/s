#!/bin/bash
set -euo pipefail

BG_URL="https://mangal.legal/media/BackgroundImage.jpg"
BG_FILE="/tmp/mangal-bg.jpg"

APPS=(
  "/Applications/Microsoft Teams.app"
  "/Applications/Microsoft Word.app"
  "/Applications/Microsoft Excel.app"
  "/Applications/Microsoft Outlook.app"
  "/Applications/Google Chrome.app"
)

echo "Lade Hintergrundbild herunter..."
curl -L "$BG_URL" -o "$BG_FILE"

echo "Leere Dock..."
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
defaults write com.apple.dock show-recents -bool false

add_app_to_dock() {
  local app_path="$1"

  if [ -d "$app_path" ]; then
    defaults write com.apple.dock persistent-apps -array-add "
    <dict>
      <key>tile-data</key>
      <dict>
        <key>file-data</key>
        <dict>
          <key>_CFURLString</key>
          <string>file://${app_path}</string>
          <key>_CFURLStringType</key>
          <integer>15</integer>
        </dict>
      </dict>
    </dict>"
    echo "Hinzugefügt: $app_path"
  else
    echo "Nicht gefunden, übersprungen: $app_path"
  fi
}

echo "Füge Apps zum Dock hinzu..."
for app in "${APPS[@]}"; do
  add_app_to_dock "$app"
done

echo "Setze Hintergrundbild..."
osascript <<APPLESCRIPT
set bgFile to POSIX file "$BG_FILE"
tell application "System Events"
	repeat with d in desktops
		set picture of d to bgFile
	end repeat
end tell
APPLESCRIPT

echo "Starte Dock neu..."
killall Dock

echo "Fertig."