# MLBB ESP — Full Setup & GitHub Tutorial

## Overview

This project is an external ESP overlay for Mobile Legends Bang Bang on Android. It reads the game's memory from a separate process, finds enemy hero positions, and renders coloured boxes with HP bars over the screen — without injecting any code into the game.

Because everything runs outside the game process, MLBB's anti-cheat has no injected library to find in its own memory map. The overlay draws at the SurfaceFlinger layer, below what WindowManager exposes to app-level scans. Root is handled by KernelSU, which can hide its own presence from the game.

The project ships as two parts: a standard Android APK (the overlay + control panel) and a KernelSU flashable zip that installs the APK and starts it automatically on boot.

---

## Requirements

**Device**
- Any Android device running MLBB, Android 10 or higher
- Bootloader unlocked
- KernelSU installed and active

**PC (for building)**
- Android Studio (latest stable) with NDK 26.1 installed
- Java 17+
- ADB installed and in your PATH
- Git

**On-device**
- KernelSU Manager app installed
- MLBB installed and able to reach the title screen at least once before setup

**Optional but recommended**
- [Il2CppDumper](https://github.com/Perfare/Il2CppDumper) on your PC — needed to verify or update offsets after each MLBB patch

---

## Step 1 — Dump Offsets From Your Device

Offsets are memory addresses inside MLBB's game library that point to hero positions, HP values, and the camera matrix. They change with every MLBB update, so you must dump them from your specific installed version before building.

**1.1 — Open MLBB and reach the title screen**

The game needs to be fully loaded so its libraries are mapped into memory.

**1.2 — Run the offset dumper from your PC**

Connect your phone via USB with ADB debugging enabled, then:

```bash
bash offset_dumper.sh
```

This script does three things automatically:
- Finds MLBB's process ID via `pidof`
- Reads `/proc/<pid>/maps` to find `libil2cpp.so`'s base address
- Pulls `libil2cpp.so` and `global-metadata.dat` to your PC for static analysis

**1.3 — Run Il2CppDumper on the pulled files**

```bash
Il2CppDumper ./libil2cpp.so ./global-metadata.dat ./dump_out/
```

This produces `dump_out/dump.cs` — a readable C# file mapping every class, field, and method in the game to its offset.

**1.4 — Find the offsets you need**

Open `dump_out/dump.cs` and search for each of these class names:

| Search term | What you are looking for |
| --- | --- |
| `ObjectManager` | The field that holds the live object list |
| `HeroEntity` | Fields: `isLocalPlayer`, `isDead`, `campId`, `currentHp`, `maxHp`, `m_transformData` |
| `Camera` | The static field `s_MainCamera` and the cached view-proj matrix field |

Note the hex offset printed next to each field in `dump.cs`. Those go in the next step.

---

## Step 2 — Update Offsets in Source Code

Open the project in Android Studio. Navigate to:

```
app/src/main/cpp/il2cpp_scanner.cpp
```

Find the `OFF` namespace at the top of the file. Replace each `FILL:` value with the hex offset you found in `dump.cs` for that field.

**How to read a dump.cs entry**

```
// Offset: 0x2D0
public float currentHp; // 0x2D0
```

The number after `Offset:` is the field offset relative to the object pointer. `OBJ_MANAGER` and `CAMERA_STATIC_PTR` use the `RVA` value instead — they are static fields relative to `libil2cpp.so`'s base.

---

## Step 3 — Build the APK

**3.1 — Open the project**

In Android Studio: File → Open → select this folder. Wait for Gradle sync to complete.

**3.2 — Set NDK version**

If prompted: SDK Manager → SDK Tools → NDK (Side by side) → install version `26.1.10909125`

**3.3 — Build release APK**

```bash
cd mlbb-esp-ksu
bash build_and_package.sh
```

Or manually: Build → Generate Signed Bundle / APK → APK → Release → Finish.

APK lands at: `app/build/outputs/apk/release/app-release.apk`

**3.4 — Verify**

```bash
adb install -r app/build/outputs/apk/release/app-release.apk
adb shell am start -n com.sys.svc/.MainActivity
adb logcat -s SysOverlay
```

Look for `MemReader init OK` and `Scan loop started`.

---

## Step 4 — Build and Flash the KernelSU Module

**4.1 — If you used `build_and_package.sh`**

The script already packaged everything into `mlbb_esp_ksu.zip`. Skip to 4.3.

**4.2 — Manual packaging**

```bash
cp app/build/outputs/apk/release/app-release.apk ksu_module/esp.apk
cd ksu_module
zip -r ../mlbb_esp_ksu.zip . -x "*.DS_Store"
```

**4.3 — Transfer to device**

```bash
adb push mlbb_esp_ksu.zip /sdcard/mlbb_esp_ksu.zip
```

**4.4 — Flash via KernelSU Manager**

1. Open KernelSU Manager
2. Tap **Modules** → **+** (Install from storage)
3. Select `mlbb_esp_ksu.zip`
4. Watch for `APK installed OK` and `Done. Reboot to start ESP on next MLBB launch.`
5. Tap **Reboot**

**4.5 — Verify**

After reboot: KernelSU Manager → Modules → `MLBB ESP` shows green.

---

## Step 5 — Using the Control Panel

After reboot, the ESP starts automatically when MLBB reaches the foreground.

A small pill appears in the top-left corner: `ESP ON` (green dot) or `ESP OFF` (grey dot). Tap to expand. Drag to move.

| Toggle | Default | What it does |
| --- | --- | --- |
| ESP | On | Master switch |
| Boxes | On | Enemy bounding boxes |
| HP Bar | On | HP bar below each box |
| HP Text | On | HP percentage |
| Allies | Off | Draw allied heroes |
| Show Dead | Off | Draw dead heroes |

Tap `×` to collapse. Settings save immediately.

**To disable:** KernelSU Manager → Modules → toggle `MLBB ESP` off → reboot.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Pill doesn't appear | Service didn't start | Check KernelSU → Modules → enabled. `adb logcat -s SysOverlay` |
| `MemReader init failed` | MLBB not running | Launch MLBB to title screen first |
| `il2cpp base not found` | MLBB not fully loaded | Wait for full load, retry |
| Boxes in wrong position | Stale camera offset | Re-dump `CAMERA_STATIC_PTR` and matrix field |
| No boxes visible | `OBJ_MANAGER` wrong | Re-dump, check `ObjectManager` RVA |
| Overlay not visible | SurfaceControl failed | Grant `SYSTEM_ALERT_WINDOW` manually in Settings → Apps |
| Module install fails | APK not in zip | Rebuild with `build_and_package.sh` |

---

## Re-Dumping Offsets After MLBB Updates

MLBB updates roughly every two weeks. When an update drops, the offsets will be stale.

```bash
# 1. Update MLBB, launch it, reach the title screen
# 2. Re-run the dumper
bash offset_dumper.sh
# 3. Re-run Il2CppDumper
Il2CppDumper ./libil2cpp.so ./global-metadata.dat ./dump_out/
# 4. Diff to find what changed
diff old_dump.cs dump_out/dump.cs | grep -E "(ObjectManager|HeroEntity|Camera|Offset)"
# 5. Update il2cpp_scanner.cpp, rebuild, reflash
bash build_and_package.sh
```

Keep a copy of the old `dump.cs` before each update so the diff is fast.
