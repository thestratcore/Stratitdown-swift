#!/bin/zsh
# Builds MarkItDown Swift.app: swift build (release) + assemble a real .app bundle.
set -eu

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

APP_NAME="MarkItDown Swift"
BUNDLE_ID="local.personal.markitdown-swift"
EXECUTABLE_NAME="MarkItDownSwift"

BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$SCRIPT_DIR/dist/${APP_NAME}.app"

echo "Building (release)..."
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/release/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
