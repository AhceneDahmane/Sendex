# Firmware Update — Sendex Vest

## Overview

The Sendex vest runs on an ESP32 microcontroller. Firmware updates are delivered to customers via:

1. **Web Serial Installer** (recommended) — browser-based, zero install
2. **esptool.py** (manual fallback) — requires Python

Current version: **v1.3.0**

### Firmware highlights (v1.3.0)

- BLE FFF0/FFF1 notify + FFF2 write commands (START/STOP/STATUS/PING/SLEEP)
- GPS NEO-6M (UART2, pins 16/17) + TinyGPSPlus
- MAX30102 PPG (I2C 0x57) — 64-sample ring buffer, adaptive peak detection, DC removal
- MPU6050 accelerometer (I2C 0x68) — net accel in JSON with speed-delta sign
- NVS flash cache — 3600 points, survives power loss and deep sleep
- Deep sleep — 60s idle + wake on GPIO 7, state saved in NVS
- DFS modem sleep — CPU 160MHz, auto 80–160MHz scaling
- Anti-stationary filter — skip if <3m AND <0.5km/h, force-send every 30s
- HR zone blue LED (PWM) — period adapts to HR
- Low battery auto-sleep — deep sleep if <10%
- Button debounce — 50ms + anti-repeat
- GPS watchdog — auto-reset if 30s no data during session
- Firmware version in every JSON payload

---

## 1. Web Serial Installer (recommended)

**URL**: `https://getsendex.com/update/`

### How it works

The page uses [ESP Web Tools](https://esphome.github.io/esp-web-tools/) — an Espressif/ESPHome library that flashes ESP32 firmware via the [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) built into Chrome/Edge.

### Customer steps

1. Connect the vest to a computer via USB (data cable, not charge-only)
2. Open `getsendex.com/update/` in Chrome or Edge (desktop)
3. Click **Install Update**
4. In the browser prompt, select the USB Serial device (CP2102 or similar)
5. Wait ~30 seconds for the flash to complete
6. "Done!" — unplug and power on the vest

### Requirements

| Item | Detail |
|------|--------|
| Browser | Chrome or Edge 89+ (desktop) |
| OS | Windows, macOS, Linux |
| USB driver | CP210x driver (auto on most systems) |
| Cable | Data-capable USB-A to Micro-USB |

---

## 2. Manual flash via esptool.py

### Prerequisites

```bash
pip install esptool
```

### Steps

1. Download the firmware `.bin` from `getsendex.com/update/sendex-firmware-{version}.bin`
2. Find the vest's serial port:
   - **Windows**: Device Manager → Ports (COM & LPT) → `COM3` (or similar)
   - **macOS**: `ls /dev/cu.*` → `/dev/cu.usbserial-XXXX`
   - **Linux**: `ls /dev/ttyUSB*` → `/dev/ttyUSB0`
3. Flash:

```bash
esptool.py --chip esp32 --port COM3 write_flash 0x0 sendex-firmware-v1.3.0.bin
```

Replace `COM3` with the actual port.

### Options

| Flag | Purpose |
|------|---------|
| `--baud 921600` | Faster flash (default 115200) |
| `--before default_reset` | Auto-reset via DTR (default) |
| `--after hard_reset` | Restart after flash |

---

## 3. Building the firmware

The firmware source is at `src/sendex_esp32.ino` (Arduino framework).

### With Arduino CLI

```bash
# Install ESP32 core if not done
arduino-cli core update-index
arduino-cli core install esp32:esp32

# Compile
arduino-cli compile --fqbn esp32:esp32:esp32 src/sendex_esp32.ino

# Generate .bin for distribution
arduino-cli elf2bin \
  src/sendex_esp32.ino.esp32.esp32.elf \
  landing/update/sendex-firmware-v1.3.0.bin
```

### With PlatformIO (recommended for development)

```ini
; platformio.ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
board_build.partitions = huge_app.csv
monitor_speed = 115200
```

```bash
pio run
pio run --target buildfs
```

The firmware `.bin` will be at `.pio/build/esp32dev/firmware.bin`.

**Note**: Copy the built binary to `landing/update/sendex-firmware-v1.3.0.bin` and update `firmware-manifest.json`.

---

## 4. Versioning and release workflow

### File layout

```
landing/update/
├── index.html                 # Web installer page
├── firmware-manifest.json     # ESP Web Tools manifest
├── sendex-firmware-v1.3.0.bin # Firmware binary
└── CHANGELOG.md               # (future) release notes
```

### Release steps

1. Bump the version in `src/sendex_esp32.ino` (`#define FIRMWARE_VERSION "v1.x.x"`)
2. Compile the firmware (see §3)
3. Copy the `.bin` to `landing/update/sendex-firmware-{version}.bin`
4. Update `firmware-manifest.json`:
   - Set `"version": "{version}"`
   - Update `"path"` to the new `.bin` filename
5. Deploy the `landing/` folder to GitHub Pages
6. Publish release notes on `getsendex.com/update/`

### firmware-manifest.json

```json
{
  "name": "Sendex Vest",
  "version": "1.3.0",
  "home_assistant_domain": "sendex",
  "builds": [
    {
      "chipFamily": "ESP32",
      "parts": [
        { "path": "sendex-firmware-v1.3.0.bin", "offset": 0 }
      ]
    }
  ]
}
```

---

## 5. Adding BLE OTA to the Flutter app (future)

For a fully in-app update experience (no USB cable needed):

1. Add an OTA partition table to the firmware:
   ```
   # partitions.csv
   nvs,      data, nvs,     0x9000,  0x5000
   otadata,  data, ota,     0xe000,  0x2000
   app0,     app,  ota_0,   0x10000, 0x1F0000
   app1,     app,  ota_1,   0x200000,0x1F0000
   ```
2. Add a BLE service + characteristic for OTA (e.g., UUID `FFF2`)
3. In `BleService`, write the new firmware binary in chunks (MTU-sized)
4. ESP32 receives chunks, writes to `app1`, then sets the boot partition and reboots

This eliminates the USB requirement entirely.

---

## 6. Troubleshooting

| Problem | Solution |
|---------|----------|
| Browser says "Web Serial not supported" | Use Chrome or Edge v89+ on desktop |
| No device appears in the prompt | Install CP210x driver; try a different USB cable (data) |
| Flash fails mid-way | Retry; lower baud rate (`--baud 115200`); check cable |
| Vest won't boot after update | Re-flash; hold reset button during flash; try erase first (`write_flash --erase-all`) |
| "A fatal error occurred: Failed to connect" | Put ESP32 in download mode: hold BOOT, tap EN, release BOOT |
