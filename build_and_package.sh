#!/bin/bash
# build_and_package.sh — one command: gradle release APK → KSU zip
# Requires: Android SDK + NDK installed, ANDROID_HOME set, Java 17+

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
KSU_DIR="$PROJECT_ROOT/ksu_module"
OUT_ZIP="$PROJECT_ROOT/mlbb_esp_ksu.zip"
APK_OUT="$PROJECT_ROOT/app/build/outputs/apk/release/app-release.apk"

echo "=== MLBB ESP — Build & Package ==="

echo "[*] Building release APK..."
cd "$PROJECT_ROOT"
./gradlew assembleRelease --quiet
[ -f "$APK_OUT" ] || { echo "[!] APK build failed."; exit 1; }
echo "[+] APK: $APK_OUT ($(du -h "$APK_OUT" | cut -f1))"

echo "[*] Injecting APK into KSU module..."
cp "$APK_OUT" "$KSU_DIR/esp.apk"

echo "[*] Packaging KSU zip..."
rm -f "$OUT_ZIP"
cd "$KSU_DIR"
zip -r "$OUT_ZIP" . -x "*.DS_Store" -x "__MACOSX/*"
echo "[+] KSU module: $OUT_ZIP ($(du -h "$OUT_ZIP" | cut -f1))"

echo ""
echo "=== Done ==="
echo "Flash $OUT_ZIP via KernelSU app → Modules → reboot."
echo "Re-dump offsets before first use: bash offset_dumper.sh"
