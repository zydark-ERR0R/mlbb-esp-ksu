#!/bin/bash
# offset_dumper.sh
# Run from PC: bash offset_dumper.sh
# Requires: adb connected, MLBB running, KernelSU root on device.

MLBB_PKG="com.mobile.legends"
ADB="adb"

echo "=== MLBB Offset Dumper ==="

echo "[*] Finding MLBB PID..."
PID=$($ADB shell "su -c 'pidof $MLBB_PKG'" 2>/dev/null | tr -d '\r' | awk '{print $NF}')
if [ -z "$PID" ]; then
    echo "[!] MLBB not running. Launch MLBB first, wait for title screen, then re-run."
    exit 1
fi
echo "[+] PID: $PID"

echo "[*] Resolving libil2cpp.so base..."
BASE=$($ADB shell "su -c 'cat /proc/$PID/maps'" 2>/dev/null \
    | grep "libil2cpp.so" \
    | grep "r-xp" \
    | head -1 \
    | awk -F'-' '{print $1}' \
    | tr -d '\r ')

if [ -z "$BASE" ]; then
    echo "[!] libil2cpp.so not found in maps. Is MLBB fully loaded?"
    exit 1
fi
echo "[+] libil2cpp.so base: 0x$BASE"

echo "[*] Pulling libil2cpp.so for Il2CppDumper..."
LIB_PATH=$($ADB shell "su -c 'cat /proc/$PID/maps'" 2>/dev/null \
    | grep "libil2cpp.so" | grep "r-xp" | head -1 \
    | awk '{print $NF}' | tr -d '\r ')

if [ -n "$LIB_PATH" ]; then
    $ADB shell "su -c 'cp $LIB_PATH /sdcard/libil2cpp.so'" 2>/dev/null
    $ADB pull /sdcard/libil2cpp.so ./libil2cpp.so 2>/dev/null
    echo "[+] Pulled to ./libil2cpp.so"
    $ADB shell "su -c 'find /data/app -name global-metadata.dat 2>/dev/null | head -1'" \
        | tr -d '\r' | while read META; do
        $ADB shell "su -c 'cp $META /sdcard/global-metadata.dat'" 2>/dev/null
        $ADB pull /sdcard/global-metadata.dat ./global-metadata.dat 2>/dev/null
        echo "[+] Pulled to ./global-metadata.dat"
    done
else
    echo "[!] Could not resolve libil2cpp.so path from maps."
fi

OBJ_MGR_OFF="0x06F12340"
echo "[*] Sanity check: reading ObjectManager ptr..."
VAL=$($ADB shell "su -c 'dd if=/proc/$PID/mem bs=1 count=8 skip=$(( 16#$BASE + 0x06F12340 )) 2>/dev/null | xxd -p'" 2>/dev/null | tr -d '\r\n ')
if [ -z "$VAL" ] || [ "$VAL" = "0000000000000000" ]; then
    echo "[!] ObjectManager ptr is null — OFF::OBJ_MANAGER is likely stale."
else
    echo "[+] ObjectManager ptr: 0x$VAL (non-null = offset likely valid)"
fi

echo ""
echo "=== Results ==="
echo "PID:          $PID"
echo "il2cpp base:  0x$BASE"
echo ""
echo "Next: Il2CppDumper ./libil2cpp.so ./global-metadata.dat ./dump_out/"
