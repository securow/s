#!/bin/bash
set -euo pipefail

BG_URL="https://raw.githubusercontent.com/securow/s/refs/heads/main/BackgroundImage.jpg"
CACHE_DIR="$HOME/Library/Caches/mangal-setup"
BG_FILE="$CACHE_DIR/mangal-bg.jpg"

APPS=(
  "/Applications/Microsoft Teams.app"
  "/Applications/Microsoft Word.app"
  "/Applications/Microsoft Excel.app"
  "/Applications/Microsoft Outlook.app"
  "/Applications/Google Chrome.app"
)

log() {
  printf '%s\n' "$1"
}

activate_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi

  if [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi

  return 1
}

ensure_homebrew() {
  if activate_brew; then
    return 0
  fi

  log "Homebrew nicht gefunden. Installiere Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! activate_brew; then
    log "Fehler: Homebrew konnte nach der Installation nicht aktiviert werden."
    exit 1
  fi
}

ensure_tools() {
  ensure_homebrew

  if ! command -v defaultbrowser >/dev/null 2>&1; then
    log "Installiere defaultbrowser ..."
    brew install defaultbrowser
  fi

  if ! command -v desktoppr >/dev/null 2>&1; then
    log "Installiere desktoppr ..."
    brew install --cask desktoppr
  fi

  hash -r
}

download_wallpaper() {
  log "Lade Hintergrundbild herunter ..."
  mkdir -p "$CACHE_DIR"
  rm -f "$BG_FILE"

  curl --fail --location --silent --show-error "$BG_URL" --output "$BG_FILE"

  if [ ! -s "$BG_FILE" ]; then
    log "Fehler: Hintergrundbild konnte nicht korrekt gespeichert werden."
    exit 1
  fi
}

clear_dock() {
  log "Leere Dock ..."
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock show-recents -bool false
}

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
    log "Hinzugefügt: $app_path"
  else
    log "Nicht gefunden, übersprungen: $app_path"
  fi
}

setup_dock() {
  clear_dock
  log "Füge Apps zum Dock hinzu ..."
  for app in "${APPS[@]}"; do
    add_app_to_dock "$app"
  done
}

set_chrome_default() {
  if [ ! -d "/Applications/Google Chrome.app" ]; then
    log "Google Chrome nicht gefunden, Standardbrowser wird übersprungen."
    return 0
  fi

  log "Setze Google Chrome als Standardbrowser ..."
  if ! defaultbrowser chrome; then
    log "defaultbrowser hat nicht funktioniert, versuche Chrome-Fallback ..."
    open -a "Google Chrome" --args --make-default-browser || true
  fi
}

set_wallpaper_fit() {
  log "Setze Hintergrundbild mit Anpassung an den Bildschirm ..."
  desktoppr "$BG_FILE"
  sleep 1
  desktoppr scale fit
  sleep 1
  desktoppr color 000000 || true
}

enable_show_on_all_spaces_best_effort() {
  log "Versuche 'In allen Spaces anzeigen' zu aktivieren ..."

  /usr/bin/osascript <<'APPLESCRIPT' || true
on enableCheckbox(procName, labelText)
	tell application "System Events"
		tell process procName
			try
				if exists checkbox labelText of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1 then
					if value of checkbox labelText of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1 is 0 then
						click checkbox labelText of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
					end if
					return true
				end if
			end try
		end tell
	end tell
	return false
end enableCheckbox

try
	tell application "System Settings" to activate
on error
	try
		tell application "Systemeinstellungen" to activate
	end try
end try

delay 1.5

tell application "System Events"
	if exists process "System Settings" then
		set procName to "System Settings"
	else if exists process "Systemeinstellungen" then
		set procName to "Systemeinstellungen"
	else
		error "System Settings process not found"
	end if

	tell process procName
		try
			click menu item "Wallpaper" of menu "View" of menu bar 1
		end try

		try
			click menu item "Hintergrundbild" of menu "Darstellung" of menu bar 1
		end try
	end tell
end tell

delay 1.5

if enableCheckbox(procName, "Show on all Spaces") is false then
	enableCheckbox(procName, "In allen Spaces anzeigen")
end if
APPLESCRIPT

  killall "System Settings" >/dev/null 2>&1 || true
  killall "Systemeinstellungen" >/dev/null 2>&1 || true

  local index_plist="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
  if [ -f "$index_plist" ]; then
    /usr/libexec/PlistBuddy \
      -c "Set :AllSpacesAndDisplays:Desktop:Content:Choices:0:Files:0:relative file:///$BG_FILE" \
      "$index_plist" >/dev/null 2>&1 || true

    killall WallpaperAgent >/dev/null 2>&1 || true
  fi
}

disable_natural_scrolling() {
  log "Deaktiviere natürliches Scrollen ..."
  defaults write -g com.apple.swipescrolldirection -bool false
}

restart_dock() {
  log "Starte Dock neu ..."
  killall Dock || true
}

main() {
  ensure_tools
  download_wallpaper
  setup_dock
  set_chrome_default
  set_wallpaper_fit
  enable_show_on_all_spaces_best_effort
  disable_natural_scrolling
  restart_dock
  log "Fertig."
}

main "$@"
