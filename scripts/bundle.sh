#!/bin/bash
set -e

# Configuration
SCHEME="Lexical"
WIDGET_TARGET="LexicalWidget"
SIMULATOR_ID="98FACCED-3F83-4A94-8D7B-F8905AAF08D1" # Default to iPhone 16e from context
DERIVED_DATA_PATH="build/derived_data"
PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator"
APP_NAME="Lexical.app"
WIDGET_NAME="LexicalWidget.appex"
BUNDLE_ID="com.lexical.Lexical"

echo "🧹 Cleaning previous build..."
rm -rf "$DERIVED_DATA_PATH"

echo "🏗️ Building Lexical App..."
xcodebuild -scheme "$SCHEME" \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

echo "🏗️ Building LexicalWidget..."
xcodebuild -scheme "Lexical-Package" \
    -target "$WIDGET_TARGET" \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

echo "📦 Bundling Widget..."
# Ensure PlugIns directory exists
mkdir -p "$PRODUCTS_PATH/$APP_NAME/PlugIns"

# Create .appex bundle structure manually since SwiftPM executable target gives us a binary
mkdir -p "$PRODUCTS_PATH/$WIDGET_NAME"
cp "$PRODUCTS_PATH/$WIDGET_TARGET" "$PRODUCTS_PATH/$WIDGET_NAME/"
cp "LexicalWidget/Info.plist" "$PRODUCTS_PATH/$WIDGET_NAME/"

# Move constructed appex into PlugIns
cp -r "$PRODUCTS_PATH/$WIDGET_NAME" "$PRODUCTS_PATH/$APP_NAME/PlugIns/"

echo "✍️ Signing..."
codesign -s - --force --deep "$PRODUCTS_PATH/$APP_NAME"

echo "📱 Installing to Simulator ($SIMULATOR_ID)..."
xcrun simctl install "$SIMULATOR_ID" "$PRODUCTS_PATH/$APP_NAME"

echo "🚀 Launching..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo "✅ Done! Widget should be available."
