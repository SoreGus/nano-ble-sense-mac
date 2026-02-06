# BLE_Mac — Arduino Nano 33 BLE Sense Rev2 Demo (macOS)

A macOS SwiftUI app that connects to **Arduino Nano 33 BLE Sense Rev2** over BLE (Nordic UART Service style), sends text commands, and visualizes live sensor data:

- Gyroscope
- Proximity
- Environment (temperature, humidity, pressure)
- Audio level (PDM mic)

This project is designed as a practical desktop demo for BLE + sensors, with dedicated windows for devices and logs.

---

## Architecture

### macOS App
- **Apple Swift version:** Swift 6.2.3
- **package tools-version** 5.10.0
- **UI:** SwiftUI
- **BLE:** CoreBluetooth
- **Build system:** Swift Package Manager 

Main components:
- `BluetoothWorker.swift`  
  BLE central manager, scan/connect, command TX, notify RX, JSON parsing, stream timers.
- `DashboardViewModel.swift`  
  Aggregates app state for dashboard and tools windows.
- `DashboardView.swift`  
  Main control panel and navigation hub.
- `DevicesWindowView.swift`  
  Device discovery and connect window.
- `LogsWindowView.swift` (if present in your project)  
  Real-time log viewer.
- Sensor-specific screens:
  - `GiroscopeView.swift`
  - `DistanceView.swift`
  - `EnvironmentView.swift`
  - `EnvironmentAudioView.swift`

### Arduino Sketch
The sketch exposes a BLE UART-like service and responds to command strings:
- `LED ON`, `LED OFF`
- `GIROSCOPE`
- `PROXIMITY`
- `TEMPERATURE`, `HUMIDITY`, `PRESSURE`
- `ENV`
- `AUDIO`

Responses are JSON lines (`\n` terminated), parsed by the macOS app.

---

## BLE Service/Characteristics

Using NUS-compatible UUIDs:

- **Service**: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX (write)**: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX (notify)**: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

---

## Requirements

### macOS
- macOS 14+ (package target)
- Swift 6.2.3

### Board
- Arduino Nano 33 BLE Sense Rev2
- Arduino IDE / Arduino CLI with libraries:
  - `ArduinoBLE`
  - `Arduino_BMI270_BMM150`
  - `Arduino_APDS9960`
  - `Arduino_HS300x`
  - `Arduino_LPS22HB`
  - `PDM`

---

## Build and Run (App)

From project root:

```bash
swift build
swift run BLEControlApp
```

Release build:

```bash
swift build -c release
```

---

## Packaging `.app` (using your `pack.sh`)

Your project includes a packaging script that:
1. Builds release binary
2. Generates/fetches app icon
3. Creates `.icns`
4. Assembles `.app` bundle
5. Signs ad-hoc
6. Verifies result

Run:

```bash
chmod +x pack.sh
./pack.sh
```

Result:
- `dist/BLEControlApp.app`

Open app:

```bash
open dist/BLEControlApp.app
```

---

## Upload Arduino Sketch

1. Open Arduino IDE
2. Select board: **Arduino Nano 33 BLE Sense Rev2**
3. Paste/upload your sketch
4. Open Serial Monitor (115200) to inspect status logs
5. Keep board powered and advertising BLE

---

## Typical Usage Flow

1. Open macOS app
2. Open **Tools → Devices**
3. Click **Search**
4. Select board (`Nano33BLE-UART`) and **Connect**
5. Start/stop streams from Dashboard controls
6. Open specialized views for richer visualizations

---

## Command Protocol (App → Board)

Examples:

- `LED ON\n`
- `LED OFF\n`
- `GIROSCOPE\n`
- `PROXIMITY\n`
- `ENV\n`
- `AUDIO\n`

JSON response examples:

```json
{"type":"gyroscope","x":0.1234,"y":-0.1022,"z":0.0123}
{"type":"proximity","value":52}
{"type":"environment","c":24.18,"rh":43.21,"hpa":1012.80}
{"type":"audio","rms":0.0331,"level":3,"peak":278}
```

---

## Notes on Streaming and Performance

- Streaming is timer-driven on the app side (polling command-based).
- Lower interval values increase responsiveness but also BLE traffic and CPU usage.
- If UI appears stale:
  - Confirm stream is enabled for that sensor
  - Check that the board is still connected
  - Verify incoming logs / JSON parse errors

---

## Troubleshooting

### 1) App crashes on launch or interaction
Run with LLDB:

```bash
lldb ./dist/BLEControlApp.app/Contents/MacOS/BLEControlApp
(lldb) run
```

If it crashes, inspect:
- backtrace (`bt`)
- thread state
- whether UI state mutations are happening on main thread

### 2) No devices found
- Confirm board is advertising
- Confirm UUIDs match in both app and sketch
- Check macOS Bluetooth permission

### 3) Connected but no data updates
- Ensure stream toggle is ON
- Verify command strings exactly match sketch handler
- Check for JSON format issues (line terminator required)

### 4) Permission issues
Your app bundle must include:
- `NSBluetoothAlwaysUsageDescription`

---

## Swift Package Manifest

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BLE_Mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BLEControlApp", targets: ["BLEControlApp"])
    ],
    targets: [
        .executableTarget(
            name: "BLEControlApp",
            path: "Sources/BLEControlApp"
        )
    ]
)
```

---

## Project Scope

This is a **demonstration app** for BLE + sensor telemetry with Arduino Nano 33 BLE Sense Rev2 on macOS.  
It prioritizes:
- clear BLE workflow,
- practical sensor integration,
- rapid UI experimentation.

---

## License

MIT

