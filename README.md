# mlbb-esp-ksu

> External ESP overlay for Mobile Legends Bang Bang — KernelSU module + Android overlay app.

![Android](https://img.shields.io/badge/Android-10%2B-green) ![KernelSU](https://img.shields.io/badge/Root-KernelSU-orange) ![Language](https://img.shields.io/badge/Language-Kotlin%20%2F%20C%2B%2B17-blue) ![License](https://img.shields.io/badge/License-MIT-lightgrey)

---

## What it does

mlbb-esp-ksu renders a real-time ESP overlay on top of Mobile Legends Bang Bang, showing enemy hero positions, HP bars, and HP percentages — without injecting any code into the game process.

**Features:**
- 🔴 Enemy bounding boxes with rounded corners and shadow pass
- 💚 HP bars (green → red as HP drops)
- 💬 HP percentage text per hero
- 🔵 Optional ally boxes
- 👻 Optional dead hero tracking
- 🎛️ Floating draggable control panel — tap the pill to expand, tap toggles to switch features on/off
- 💾 Settings persist across reboots
- 🔔 Silent background notification with tap-to-open panel

**Bypass approach:**
| Detection vector | Bypass |
| --- | --- |
| Root detection | KernelSU built-in su hide |
| Process scanning | `prctl` rename to `com.android.phone` via `service.sh` |
| Overlay scanning | Renders at SurfaceFlinger layer via `SurfaceControl` — not in `WindowManager.getWindows()` |
| Memory injection detection | External `/proc/pid/mem` read only — our `.so` never maps into MLBB |
| Timing fingerprint | ±15ms jitter on 50ms scan loop |

---

## Requirements

- Android 10+ (API 29+)
- Bootloader unlocked
- KernelSU installed and active
- Android Studio + NDK 26.1 (for building)
- Java 17+
- ADB
- [Il2CppDumper](https://github.com/Perfare/Il2CppDumper) (for offset dumping)

---

## Quick start

See **[SETUP.md](SETUP.md)** for the full step-by-step guide.

Short version:
```bash
# 1. Launch MLBB on device, reach title screen
# 2. Dump offsets
bash offset_dumper.sh
# 3. Update OFF namespace in app/src/main/cpp/il2cpp_scanner.cpp
# 4. Build + flash
bash build_and_package.sh
# adb push mlbb_esp_ksu.zip /sdcard/ → KernelSU app → Modules → flash → reboot
```

---

## Project structure

```
mlbb-esp-ksu/
├── app/src/main/
│   ├── cpp/
│   │   ├── mem_reader.cpp        — /proc/pid/mem reader (JNI, no ptrace)
│   │   ├── il2cpp_scanner.cpp    — IL2CPP entity walker + W2S projection
│   │   └── CMakeLists.txt
│   └── kotlin/com/sys/svc/
│       ├── MemReader.kt          — JNI wrapper + PID/base resolver
│       ├── EntityScanner.kt      — hero scan + world-to-screen
│       ├── BypassManager.kt      — anti-cheat evasion layer
│       ├── OverlayRenderer.kt    — SurfaceControl ESP renderer
│       ├── EspService.kt         — foreground service + scan loop
│       ├── EspConfig.kt          — shared config singleton
│       ├── ControlPanel.kt       — floating draggable UI panel
│       ├── ControlActivity.kt    — notification tap trampoline
│       └── MainActivity.kt       — silent launcher
├── ksu_module/
│   ├── module.prop
│   ├── customize.sh              — APK installer at flash time
│   └── service.sh                — boot service: process rename + auto-start
├── offset_dumper.sh              — PC script: pulls libil2cpp.so + validates offsets
└── build_and_package.sh          — one command: APK → KSU zip
```

---

## Offsets

Offsets in `app/src/main/cpp/il2cpp_scanner.cpp` are **placeholders** — they must be dumped from your installed MLBB version before the ESP will work.

Re-dump after every MLBB update:
```bash
bash offset_dumper.sh
Il2CppDumper ./libil2cpp.so ./global-metadata.dat ./dump_out/
# Update OFF namespace → rebuild
```

Open an issue if the offsets are stale and you have verified new ones.

---

## Current offset status

| MLBB version | Status | Date |
| --- | --- | --- |
| 1.8.xx (placeholder) | ⚠️ FILL before use | — |

---

## License

MIT — see [LICENSE](LICENSE)
