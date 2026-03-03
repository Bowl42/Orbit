#!/bin/bash
set -euo pipefail

APP_NAME="Orbit"
BUNDLE_ID="com.bowl42.Orbit"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Build release
echo "Building ${APP_NAME}..."
swift build -c release 2>&1

BINARY=".build/release/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Build failed, binary not found at $BINARY"
    exit 1
fi

# Remove old bundle if exists
if [ -d "$APP_DIR" ]; then
    echo "Removing old ${APP_DIR}..."
    rm -rf "$APP_DIR"
fi

# Create .app bundle structure
echo "Creating ${APP_DIR}..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS/${APP_NAME}"

# Copy Info.plist
cp "Orbit/Info.plist" "$CONTENTS/Info.plist"

# Copy bundle resources if they exist
BUNDLE_RESOURCES=".build/release/Orbit_Orbit.bundle"
if [ -d "$BUNDLE_RESOURCES" ]; then
    cp -R "$BUNDLE_RESOURCES" "$RESOURCES/"
fi

# Sign with developer identity so Accessibility/Input Monitoring permissions
# persist across rebuilds (ad-hoc signing changes hash every build, breaking TCC)
codesign --force --sign "Apple Development" "$APP_DIR"

echo ""
echo "✓ ${APP_DIR} created successfully"
