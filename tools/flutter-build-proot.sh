#!/bin/sh
# Run Flutter builds inside Ubuntu proot with QEMU emulation for x86_64
# Android SDK tools (aapt2, adb). Flutter/Dart/Gradle/Java run natively on ARM64.
# Usage: sh tools/flutter-build-proot.sh <flutter build args...>
# Example: sh tools/flutter-build-proot.sh apk --debug
FLUTTER_DIR=/data/data/ai.antigem/files/home/flutter-sdk
PROJ_DIR=/data/data/ai.antigem/files/home/projects/zara
CMD="export PATH=$FLUTTER_DIR/bin:\$PATH; export ANDROID_HOME=/opt/android-sdk; export ANDROID_SDK_ROOT=/opt/android-sdk; export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64; cd $PROJ_DIR; flutter"
for arg in "$@"; do
  quoted=$(printf %s "$arg" | sed "s/'/'\\\\''/g; s/^/'/; s/\$/'/")
  CMD="$CMD $quoted"
done
exec proot-distro login ubuntu -- proot --qemu="qemu-x86_64-static -L /usr/x86_64-linux-gnu" sh -c "$CMD"
