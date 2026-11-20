#!/bin/sh
# Run Flutter 3.50.1 (ARM64) inside the Ubuntu proot container.
# Usage: sh tools/flutter-proot.sh <flutter args...>
# Example: sh tools/flutter-proot.sh test
FLUTTER_DIR=/data/data/ai.antigem/files/home/flutter-sdk
PROJ_DIR=/data/data/ai.antigem/files/home/projects/zara
exec proot-distro login ubuntu -- sh -c "export PATH=$FLUTTER_DIR/bin:\$PATH; export ANDROID_HOME=/opt/android-sdk; export ANDROID_SDK_ROOT=/opt/android-sdk; cd $PROJ_DIR; flutter $*"
