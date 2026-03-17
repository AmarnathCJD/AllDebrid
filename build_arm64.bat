@echo off
cd telegram\ffi
set GOOS=android
set GOARCH=arm64
set CGO_ENABLED=1
set ANDROID_NDK_HOME=C:\Users\Amarnath\scoop\persist\android-clt\ndk\29.0.14206865
set CC=%ANDROID_NDK_HOME%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android29-clang.cmd
echo Building for arm64-v8a...
go build -buildmode=c-shared -o ..\..\android\app\src\main\jniLibs\arm64-v8a\libtg_fetch.so .
if %ERRORLEVEL% EQU 0 (
    echo ✓ Built arm64-v8a successfully
    del /Q ..\..\android\app\src\main\jniLibs\arm64-v8a\libtg_fetch.h 2>nul
    del /Q libtg_fetch.h 2>nul
    echo Removed header files
) else (
    echo ✗ Build failed
)
