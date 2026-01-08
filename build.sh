#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Force fresh install to ensure no cache issues with old versions
rm -rf flutter

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# IMPORTANT: Prepend to PATH to ensure we use this flutter, not any system-installed one
export PATH="$(pwd)/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Flutter Doctor:"
flutter doctor

echo "Enabling web support..."
flutter config --enable-web

echo "Getting dependencies..."
flutter pub get

echo "Building web app..."
# Build with CanvasKit renderer for better performance in games
flutter build web --release --web-renderer canvaskit

echo "Build complete. Checking output..."
if [ -d "build/web" ]; then
  echo "build/web directory exists. Contents:"
  ls -la build/web
else
  echo "Error: build/web directory does not exist!"
  exit 1
fi

echo "Done."
