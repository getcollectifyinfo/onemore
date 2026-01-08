#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Define Flutter binary path explicitly
FLUTTER_ROOT="$(pwd)/flutter"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"

# Force fresh install
rm -rf flutter

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

echo "Verifying Flutter binary..."
if [ ! -f "$FLUTTER_BIN" ]; then
  echo "Error: Flutter binary not found at $FLUTTER_BIN"
  exit 1
fi

# Export path just in case, but we will use FLUTTER_BIN variable
export PATH="$FLUTTER_ROOT/bin:$PATH"

echo "Flutter version:"
"$FLUTTER_BIN" --version

echo "Enabling web support..."
"$FLUTTER_BIN" config --enable-web

echo "Cleaning..."
"$FLUTTER_BIN" clean

echo "Getting dependencies..."
"$FLUTTER_BIN" pub get

echo "Building web app..."
# Removing --web-renderer flag temporarily to resolve "option not found" error.
# Default behavior is 'auto' which is fine for now.
"$FLUTTER_BIN" build web --release

echo "Build complete. Checking output..."
if [ -d "build/web" ]; then
  echo "build/web directory exists. Contents:"
  ls -la build/web
else
  echo "Error: build/web directory does not exist!"
  exit 1
fi

echo "Done."
