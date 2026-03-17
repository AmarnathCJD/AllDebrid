#!/bin/bash
cd telegram/ffi
export GOOS=android
export GOARCH=arm64
export CGO_ENABLED=1
export ANDROID_NDK_HOME="/c/Users/Amarnath/scoop/persist/android-clt/ndk/29.0.14206865"
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64/bin:$PATH"
export CC="aarch64-linux-android29-clang"

echo "Building for arm64-v8a..."
go build -buildmode=c-shared -o ../android/app/src/main/jniLibs/arm64-v8a/libtg_fetch.so .

if [ $? -eq 0 ]; then
    echo "✓ Built arm64-v8a successfully"
else
    echo "✗ Build failed"
fi
