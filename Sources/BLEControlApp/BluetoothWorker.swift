//
//  BluetoothWorker.swift
//  BLEControlApp
//
//  Handles BLE scanning/connection, NUS RX/TX messaging, sensor stream polling,
//  and JSON parsing for gyroscope, proximity, environment, and audio samples.
//
import Foundation
import CoreBluetooth
import Combine

final class BluetoothWorker: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Device: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
        let peripheral: CBPeripheral
    }

    struct GyroSample: Equatable {
        let x: Double
        let y: Double
        let z: Double
        static let zero = GyroSample(x: 0, y: 0, z: 0)
    }

    struct EnvironmentSample: Equatable {
        let temperatureC: Double
        let humidityRH: Double
        let pressureHpa: Double
        static let zero = EnvironmentSample(temperatureC: 0, humidityRH: 0, pressureHpa: 0)
    }

    struct AudioSample: Equatable {
        let rms: Double
        let level: Int
        let peak: Int
        static let zero = AudioSample(rms: 0, level: 0, peak: 0)
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var logs: [String] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isBluetoothReady = false
    @Published private(set) var connectedName: String?
    @Published private(set) var canSend = false

    @Published private(set) var gyroSample: GyroSample = .zero
    @Published private(set) var lastGyroAt: Date?

    @Published private(set) var proximityValue: Int = 0
    @Published private(set) var proximityNormalized: Double = 0
    @Published private(set) var lastProximityAt: Date?

    @Published private(set) var environmentSample: EnvironmentSample = .zero
    @Published private(set) var lastEnvironmentAt: Date?

    @Published private(set) var audioSample: AudioSample = .zero
    @Published private(set) var lastAudioAt: Date?

    private var central: CBCentralManager!
    private var discovered: [UUID: Device] = [:]
    private var currentPeripheral: CBPeripheral?
    private var rxChar: CBCharacteristic?
    private var txChar: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private var gyroTimer: DispatchSourceTimer?
    private var proximityTimer: DispatchSourceTimer?
    private var environmentTimer: DispatchSourceTimer?
    private var audioTimer: DispatchSourceTimer?
    private var rxLineBuffer = ""

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    deinit {
        stopGyroStreaming()
        stopProximityStreaming()
        stopEnvironmentStreaming()
        stopAudioStreaming()
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }

    func search() {
        guard central.state == .poweredOn else {
            appendLog("Bluetooth is not ready.")
            return
        }
        devices.removeAll()
        discovered.removeAll()
        isScanning = true
        appendLog("Scanning...")
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopSearch() {
        central.stopScan()
        isScanning = false
        appendLog("Scan stopped.")
    }

    func connect(_ device: Device) {
        stopSearch()
        appendLog("Connecting to \(device.name)...")
        currentPeripheral = device.peripheral
        currentPeripheral?.delegate = self
        central.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        stopGyroStreaming()
        stopProximityStreaming()
        stopEnvironmentStreaming()
        stopAudioStreaming()
        guard let p = currentPeripheral else { return }
        central.cancelPeripheralConnection(p)
    }

    func ledOn() { send("LED ON\n") }
    func ledOff() { send("LED OFF\n") }
    func ping() { send("PING\n") }

    func requestEnvironment() { send("ENV\n") }
    func requestAudio() { send("AUDIO\n") }

    func startGyroStreaming(intervalMs: Int = 80) {
        guard canSend else { appendLog("No connection for GYROSCOPE."); return }
        if gyroTimer != nil { return }
        appendLog("Gyro stream ON (\(intervalMs)ms)")
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(30, intervalMs)))
        timer.setEventHandler { [weak self] in self?.send("GIROSCOPE\n", log: false) }
        timer.resume()
        gyroTimer = timer
    }

    func stopGyroStreaming() { if gyroTimer != nil { appendLog("Gyro stream OFF") }; gyroTimer?.cancel(); gyroTimer = nil }

    func startProximityStreaming(intervalMs: Int = 120) {
        guard canSend else { appendLog("No connection for PROXIMITY."); return }
        if proximityTimer != nil { return }
        appendLog("Proximity stream ON (\(intervalMs)ms)")
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(40, intervalMs)))
        timer.setEventHandler { [weak self] in self?.send("PROXIMITY\n", log: false) }
        timer.resume()
        proximityTimer = timer
    }

    func stopProximityStreaming() { if proximityTimer != nil { appendLog("Proximity stream OFF") }; proximityTimer?.cancel(); proximityTimer = nil }

    func startEnvironmentStreaming(intervalMs: Int = 500) {
        guard canSend else { appendLog("No connection for ENV."); return }
        if environmentTimer != nil { return }
        appendLog("Environment stream ON (\(intervalMs)ms)")
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(150, intervalMs)))
        timer.setEventHandler { [weak self] in self?.send("ENV\n", log: false) }
        timer.resume()
        environmentTimer = timer
    }

    func stopEnvironmentStreaming() { if environmentTimer != nil { appendLog("Environment stream OFF") }; environmentTimer?.cancel(); environmentTimer = nil }

    func startAudioStreaming(intervalMs: Int = 120) {
        guard canSend else { appendLog("No connection for AUDIO."); return }
        if audioTimer != nil { return }
        appendLog("Audio stream ON (\(intervalMs)ms)")
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(50, intervalMs)))
        timer.setEventHandler { [weak self] in self?.send("AUDIO\n", log: false) }
        timer.resume()
        audioTimer = timer
    }

    func stopAudioStreaming() { if audioTimer != nil { appendLog("Audio stream OFF") }; audioTimer?.cancel(); audioTimer = nil }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.isBluetoothReady = (central.state == .poweredOn)
            self.appendLog("Central state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let dev = Device(id: peripheral.identifier, name: peripheral.name ?? "Unknown", rssi: RSSI.intValue, peripheral: peripheral)
        discovered[dev.id] = dev
        DispatchQueue.main.async { self.devices = self.discovered.values.sorted { $0.rssi > $1.rssi } }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.connectedName = peripheral.name ?? "Unknown"; self.appendLog("Connected: \(self.connectedName ?? "-")") }
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { self.appendLog("Connection failed: \(error?.localizedDescription ?? "unknown")"); self.canSend = false }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.appendLog("Disconnected.")
            self.connectedName = nil
            self.canSend = false
            self.rxChar = nil
            self.txChar = nil
            self.stopGyroStreaming()
            self.stopProximityStreaming()
            self.stopEnvironmentStreaming()
            self.stopAudioStreaming()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { DispatchQueue.main.async { self.appendLog("discoverServices error: \(error.localizedDescription)") }; return }
        guard let services = peripheral.services else { return }
        for s in services where s.uuid == serviceUUID { peripheral.discoverCharacteristics([rxUUID, txUUID], for: s) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { DispatchQueue.main.async { self.appendLog("characteristics error: \(error.localizedDescription)") }; return }
        guard let chars = service.characteristics else { return }
        for c in chars { if c.uuid == rxUUID { rxChar = c }; if c.uuid == txUUID { txChar = c } }
        if let tx = txChar { peripheral.setNotifyValue(true, for: tx); DispatchQueue.main.async { self.appendLog("Notify enabled.") } }
        DispatchQueue.main.async { self.canSend = (self.rxChar != nil) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { DispatchQueue.main.async { self.appendLog("RX error: \(error.localizedDescription)") }; return }
        guard let data = characteristic.value else { return }
        guard let text = String(data: data, encoding: .utf8) else { DispatchQueue.main.async { self.appendLog("RX <= \(data.count) bytes (binary)") }; return }
        handleIncomingText(text)
    }

    private func handleIncomingText(_ chunk: String) {
        rxLineBuffer += chunk
        while let nl = rxLineBuffer.firstIndex(of: "\n") {
            let line = String(rxLineBuffer[..<nl]).trimmingCharacters(in: .whitespacesAndNewlines)
            rxLineBuffer.removeSubrange(...nl)
            guard !line.isEmpty else { continue }

            if parseGyro(line) || parseProximity(line) || parseEnvironment(line) || parseTemperature(line) || parseHumidity(line) || parsePressure(line) || parseAudio(line) { continue }
            DispatchQueue.main.async { self.appendLog("RX <= \(line)") }
        }
    }

    private func parseGyro(_ line: String) -> Bool {
        guard line.contains("\"type\":\"gyroscope\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let x: Double?; let y: Double?; let z: Double?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("GYRO error: \(e)") }; return true }
            guard let x = p.x, let y = p.y, let z = p.z else { return true }
            DispatchQueue.main.async { self.gyroSample = .init(x: x, y: y, z: z); self.lastGyroAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("GYRO parse fail: \(line)") } }
        return true
    }

    private func parseProximity(_ line: String) -> Bool {
        guard line.contains("\"type\":\"proximity\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let value: Int?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("PROX error: \(e)") }; return true }
            guard let raw = p.value else { return true }
            let clamped = max(0, min(raw, 255))
            DispatchQueue.main.async { self.proximityValue = clamped; self.proximityNormalized = Double(clamped) / 255.0; self.lastProximityAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("PROX parse fail: \(line)") } }
        return true
    }

    private func parseEnvironment(_ line: String) -> Bool {
        guard line.contains("\"type\":\"environment\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let c: Double?; let rh: Double?; let hpa: Double?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("ENV error: \(e)") }; return true }
            guard let t = p.c, let h = p.rh, let pHpa = p.hpa else { return true }
            DispatchQueue.main.async { self.environmentSample = .init(temperatureC: t, humidityRH: h, pressureHpa: pHpa); self.lastEnvironmentAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("ENV parse fail: \(line)") } }
        return true
    }

    private func parseTemperature(_ line: String) -> Bool {
        guard line.contains("\"type\":\"temperature\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let c: Double?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("TEMP error: \(e)") }; return true }
            guard let t = p.c else { return true }
            DispatchQueue.main.async { self.environmentSample = .init(temperatureC: t, humidityRH: self.environmentSample.humidityRH, pressureHpa: self.environmentSample.pressureHpa); self.lastEnvironmentAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("TEMP parse fail: \(line)") } }
        return true
    }

    private func parseHumidity(_ line: String) -> Bool {
        guard line.contains("\"type\":\"humidity\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let rh: Double?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("HUM error: \(e)") }; return true }
            guard let h = p.rh else { return true }
            DispatchQueue.main.async { self.environmentSample = .init(temperatureC: self.environmentSample.temperatureC, humidityRH: h, pressureHpa: self.environmentSample.pressureHpa); self.lastEnvironmentAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("HUM parse fail: \(line)") } }
        return true
    }

    private func parsePressure(_ line: String) -> Bool {
        guard line.contains("\"type\":\"pressure\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let hpa: Double?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("PRESS error: \(e)") }; return true }
            guard let pHpa = p.hpa else { return true }
            DispatchQueue.main.async { self.environmentSample = .init(temperatureC: self.environmentSample.temperatureC, humidityRH: self.environmentSample.humidityRH, pressureHpa: pHpa); self.lastEnvironmentAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("PRESS parse fail: \(line)") } }
        return true
    }

    private func parseAudio(_ line: String) -> Bool {
        guard line.contains("\"type\":\"audio\""), let data = line.data(using: .utf8) else { return false }
        struct P: Decodable { let rms: Double?; let level: Int?; let peak: Int?; let error: String? }
        do {
            let p = try JSONDecoder().decode(P.self, from: data)
            if let e = p.error { DispatchQueue.main.async { self.appendLog("AUDIO error: \(e)") }; return true }
            let rms = min(max(p.rms ?? 0, 0), 1)
            let level = min(max(p.level ?? Int((rms * 100).rounded()), 0), 100)
            let peak = min(max(p.peak ?? 0, 0), 32767)
            DispatchQueue.main.async { self.audioSample = .init(rms: rms, level: level, peak: peak); self.lastAudioAt = Date() }
        } catch { DispatchQueue.main.async { self.appendLog("AUDIO parse fail: \(line)") } }
        return true
    }

    private func send(_ text: String, log: Bool = true) {
        guard let p = currentPeripheral, let rx = rxChar else { if log { DispatchQueue.main.async { self.appendLog("Not connected.") } }; return }
        let data = Data(text.utf8)
        let type: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(data, for: rx, type: type)
        if log { DispatchQueue.main.async { self.appendLog("TX => \(text.trimmingCharacters(in: .newlines))") } }
    }

    private func appendLog(_ s: String) {
        logs.append(s)
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
    }
}
