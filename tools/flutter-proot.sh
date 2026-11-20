#!/bin/sh
# Run Flutter 3.50.1 (ARM64) inside the Ubuntu proot container.
# Usage: sh tools/flutter-proot.sh <flutter args...>
# Example: sh tools/flutter-proot.sh test
FLUTTER_DIR=/data/data/ai.antigem/files/usr/tmp/opencode/flutter
PROJ_DIR=/data/data/ai.antigem/files/home/projects/zara
exec proot-distro login ubuntu -- sh -c "export PATH=$FLUTTER_DIR/bin:\$PATH; cd $PROJ_DIR; flutter $*"
