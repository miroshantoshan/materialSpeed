set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/dist/materialSpeed.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/materialSpeed" "$APP/Contents/MacOS/materialSpeed"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"

echo "$APP"
