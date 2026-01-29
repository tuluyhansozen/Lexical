#!/bin/bash
set -x

PROJECT_ROOT="/Users/tuluyhan/projects/son"
DERIVED_DATA_ROOT="/Users/tuluyhan/Library/Developer/Xcode/DerivedData"

# Find latest build product (safely)
# We assume the directory name starts with 'Lexical-'
BINARY_DIR=$(find "$DERIVED_DATA_ROOT" -name "Lexical-*" -type d -print -quit)
if [ -z "$BINARY_DIR" ]; then
    echo "Could not find DerivedData for Lexical"
    exit 1
fi

BINARY="$BINARY_DIR/Build/Products/Debug-iphonesimulator/Lexical"
APP_DIR="$BINARY_DIR/Build/Products/Debug-iphonesimulator/Lexical.app"
INFO_PLIST="$PROJECT_ROOT/Lexical/Info.plist"

if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY"
    exit 1
fi

echo "Packaging $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp "$BINARY" "$APP_DIR/"
cp "$INFO_PLIST" "$APP_DIR/Info.plist"
echo "APPL????" > "$APP_DIR/PkgInfo"

# CodeSign (AdRoc)
codesign --force --sign - --timestamp=none "$APP_DIR"

echo "Installing to booted simulator..."
xcrun simctl install booted "$APP_DIR"

echo "Launching..."
xcrun simctl launch booted com.lexical.Lexical
