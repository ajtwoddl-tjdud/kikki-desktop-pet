#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-universal}"
case "$MODE" in
    universal) ARCHS=(arm64 x86_64); BUILD="$ROOT/outputs/macos" ;;
    --native) ARCHS=("$(uname -m)"); BUILD="$ROOT/outputs/macos-dev" ;;
    *) echo "usage: $0 [--native]" >&2; exit 2 ;;
esac
APP="$BUILD/Kikki.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile both slices without third-party dependencies or an Xcode project.
for ARCH in "${ARCHS[@]}"; do
    xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx12.0" \
        -framework AppKit -framework Carbon \
        "$ROOT"/macos/Sources/*.swift -o "$BUILD/Kikki-$ARCH"
done
if [ "$MODE" = universal ]; then
    xcrun lipo -create "$BUILD/Kikki-arm64" "$BUILD/Kikki-x86_64" -output "$APP/Contents/MacOS/Kikki"
else
    cp "$BUILD/Kikki-${ARCHS[0]}" "$APP/Contents/MacOS/Kikki"
fi
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/assets"
cp "$ROOT"/assets/*.png "$APP/Contents/Resources/assets/"
# Only runtime images/manifest are bundled; editable Blender sources stay in the repo.
mkdir -p "$APP/Contents/Resources/assets/rendered-3d"
cp -R "$ROOT/assets/rendered-3d/frames" "$APP/Contents/Resources/assets/rendered-3d/"
cp "$ROOT/assets/rendered-3d/manifest.json" "$APP/Contents/Resources/assets/rendered-3d/"
cp "$ROOT/assets/mischief.json" "$APP/Contents/Resources/assets/"
plutil -lint "$APP/Contents/Info.plist"
# Local ad-hoc signing. Developer ID signing/notarization is a separate release step.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
for ARCH in "${ARCHS[@]}"; do
    xcrun lipo "$APP/Contents/MacOS/Kikki" -verify_arch "$ARCH"
done
"$APP/Contents/MacOS/Kikki" --self-test
echo "Built: $APP"
if [ "$MODE" = universal ]; then
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$BUILD/Kikki-macOS.zip"
    echo "ZIP: $BUILD/Kikki-macOS.zip"
fi
