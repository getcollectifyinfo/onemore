#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Install Flutter if not present
if [ -d "flutter" ]; then
  echo "Flutter directory exists. Skipping clone."
else
  echo "Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "Flutter version:"
flutter --version

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
