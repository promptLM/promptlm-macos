#!/usr/bin/env bash
# Build PromptLMMac, wrap into a .app bundle, install to ~/Applications.
#
# Usage:
#   ./install.sh                # install to ~/Applications
#   ./install.sh --system       # install to /Applications (uses sudo for copy)
#   ./install.sh --launch       # also start the app after install
#   ./install.sh --uninstall    # remove the installed bundle
#
# Notes:
# - The app is ad-hoc signed. macOS will keep it quarantined-friendly without a
#   Developer ID, but on first launch you may need to right-click → Open and
#   confirm. Real signing/notarization comes later in the roadmap.
# - LSUIElement=true means the app has no Dock icon — only the menu bar item.

set -euo pipefail

APP_NAME="PromptLMMac"
DISPLAY_NAME="promptLM"
BUNDLE_ID="dev.promptlm.mac"
VERSION="0.1.0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INSTALL_DIR="$HOME/Applications"
LAUNCH_AFTER=0
UNINSTALL=0
USE_SUDO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --system)    INSTALL_DIR="/Applications"; USE_SUDO="sudo" ;;
        --launch)    LAUNCH_AFTER=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

APP_PATH="$INSTALL_DIR/$APP_NAME.app"

if [ "$UNINSTALL" -eq 1 ]; then
    echo "==> Stopping any running instance"
    pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    echo "==> Removing $APP_PATH"
    $USE_SUDO rm -rf "$APP_PATH"
    echo "Done."
    exit 0
fi

cd "$SCRIPT_DIR"

if ! command -v swift >/dev/null 2>&1; then
    echo "swift not found. Install Xcode or the Swift toolchain." >&2
    exit 1
fi

echo "==> Building $APP_NAME (release)"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [ ! -x "$BIN_PATH" ]; then
    echo "Binary not found at $BIN_PATH" >&2
    exit 1
fi

STAGE_DIR="$(mktemp -d)"
STAGE_APP="$STAGE_DIR/$APP_NAME.app"

echo "==> Assembling .app bundle"
mkdir -p "$STAGE_APP/Contents/MacOS"
mkdir -p "$STAGE_APP/Contents/Resources"
cp "$BIN_PATH" "$STAGE_APP/Contents/MacOS/$APP_NAME"
chmod +x "$STAGE_APP/Contents/MacOS/$APP_NAME"

cat > "$STAGE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 promptLM contributors</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
codesign --force --sign - "$STAGE_APP" >/dev/null

echo "==> Stopping any running instance"
# Without this, LaunchServices keeps the old PID registered for the bundle ID
# and a subsequent `open` will activate the stale process instead of starting
# the freshly installed one.
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
# Give launchd a moment to release the registration.
for _ in 1 2 3 4 5; do
    pgrep -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null || break
    sleep 0.2
done

echo "==> Installing to $APP_PATH"
mkdir -p "$INSTALL_DIR" 2>/dev/null || $USE_SUDO mkdir -p "$INSTALL_DIR"
$USE_SUDO rm -rf "$APP_PATH"
$USE_SUDO cp -R "$STAGE_APP" "$APP_PATH"
rm -rf "$STAGE_DIR"

# Refresh LaunchServices registration so `open` resolves to the new bundle.
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
    -f "$APP_PATH" 2>/dev/null || true

# Strip quarantine attribute that may be inherited from build output
$USE_SUDO xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo
echo "Installed: $APP_PATH"
echo "Launch:    open \"$APP_PATH\""
echo "Quit:      use the menu bar icon -> Quit promptLM"
echo "Uninstall: ./install.sh --uninstall${USE_SUDO:+ --system}"

if [ "$LAUNCH_AFTER" -eq 1 ]; then
    echo "==> Launching"
    open "$APP_PATH"
fi
