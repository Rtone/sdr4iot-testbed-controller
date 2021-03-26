#!/bin/bash


node="$1"
file="screenshot-$1-$(date +%Y-%m-%d_%H-%M-%S).png"
ssh -F ssh-config "$1" '/android/android-sdk-linux/platform-tools/adb shell input keyevent 82'
ssh -F ssh-config "$1" '/android/android-sdk-linux/platform-tools/adb exec-out screencap -p' > "$file"
echo "$node: $file"
