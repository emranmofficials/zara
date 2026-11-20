#!/bin/sh
# Run Flutter 3.50.1 (ARM64) inside the Ubuntu proot container.
# Usage: sh tools/flutter-proot.sh <flutter args...>
# Example: sh tools/flutter-proot.sh test
FLUTTER_DIR=/data/data/ai.antigem/files/home/flutter-sdk
PROJ_DIR=/data/data/ai.antigem/files/home/projects/zara
CMD="export PATH=$FLUTTER_DIR/bin:\$PATH; export ANDROID_HOME=/opt/android-sdk; export ANDROID_SDK_ROOT=/opt/android-sdk; cd $PROJ_DIR; flutter"
for arg in "$@"; do
  quoted=$(printf %s "$arg" | sed "s/'/'\\\\''/g; s/^/'/; s/\$/'/")
  CMD="$CMD $quoted"
done
exec proot-distro login ubuntu -- sh -c "$CMD"
