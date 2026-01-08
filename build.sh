#!/bin/bash

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Enabling web support..."
flutter config --enable-web

echo "Getting dependencies..."
flutter pub get

echo "Building web app..."
# Build with CanvasKit renderer for better performance in games
flutter build web --release --web-renderer canvaskit

echo "Build complete. Listing build directory:"
ls -R build/web

echo "Current directory:"
pwd
