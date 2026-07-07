#!/bin/zsh
# Build the 20-20-20 menu bar app. Usage:
#   ./build.sh            build into build/20-20-20.app
#   ./build.sh install    build, copy to ~/Applications, and launch
set -euo pipefail
cd "$(dirname "$0")"

ARCH=$(uname -m)
BUILD=build
APP="$BUILD/20-20-20.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# App icon (regenerated only when the generator script changes)
if [[ ! -f "$BUILD/AppIcon.icns" || tools/makeicon.swift -nt "$BUILD/AppIcon.icns" ]]; then
    swift tools/makeicon.swift "$BUILD/AppIcon.iconset"
    iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 5 -parse-as-library \
    -target "$ARCH-apple-macos14.0" \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/TwentyTwentyTwenty"

codesign --force -s - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
    mkdir -p ~/Applications
    # Quit a running copy before replacing it
    pkill -x TwentyTwentyTwenty 2>/dev/null || true
    rm -rf ~/Applications/20-20-20.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/20-20-20.app
    echo "Installed and launched ~/Applications/20-20-20.app"
fi
