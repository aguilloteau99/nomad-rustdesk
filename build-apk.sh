#!/usr/bin/env bash
set -euo pipefail

export ANDROID_NDK_HOME=/home/userpr/Android/Sdk/ndk/27.0.12077973
export VCPKG_ROOT=/home/userpr/vcpkg
SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
CLANG_BUILTIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/18/include"
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$SYSROOT -nostdinc -isystem $CLANG_BUILTIN -isystem $SYSROOT/usr/include -isystem $SYSROOT/usr/include/aarch64-linux-android"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

echo "=== Build Environment ==="
echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
echo "VCPKG_ROOT=$VCPKG_ROOT"
echo "JAVA_HOME=$JAVA_HOME"
echo ""

cd /home/userpr/rustdesk

echo "=== Step 1: Building native lib with cargo-ndk ==="
cargo ndk --platform 21 --target aarch64-linux-android build --release --features flutter
echo ""

echo "=== Step 2: Copying native lib ==="
cp target/aarch64-linux-android/release/liblibrustdesk.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
ls -la flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
echo ""

echo "=== Step 3: Building APK ==="
cd flutter
flutter build apk --debug
echo ""

echo "=== Step 4: Verify APK ==="
ls -la build/app/outputs/flutter-apk/app-debug.apk
echo ""
echo "=== BUILD COMPLETE ==="
