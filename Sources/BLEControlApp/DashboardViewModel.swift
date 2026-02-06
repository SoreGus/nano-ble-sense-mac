//
//  DashboardViewModel.swift
//  BLEControlApp
//
//  Created by Gustavo on 2026-02-06.
//
import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var devices: [BluetoothWorker.Device] = []
    @Published var logs: [String] = []
    @Published var isScanning = false
    @Published var isBluetoothReady = false
    @Published var connectedName: String?
    @Published var canSend = false

    @Published var gyroSample: BluetoothWorker.GyroSample = .zero
    @Published var lastGyroText: String = "—"

    @Published var proximityValue: Int = 0
    @Published var proximityPercentText: String = "0%"

    @Published var temperatureText: String = "—"
    @Published var humidityText: String = "—"
    @Published var pressureText: String = "—"

    @Published var audioLevelText: String = "—"
    @Published var audioPeakText: String = "—"
    @Published var audioRmsText: String = "—"

    // MARK: - Stream Controls
    @Published var isGyroStreaming = false
    @Published var isProximityStreaming = false
    @Published var isEnvironmentStreaming = false
    @Published var isAudioStreaming = false

    @Published var gyroIntervalMs: Int = 80
    @Published var proximityIntervalMs: Int = 120
    @Published var environmentIntervalMs: Int = 500
    @Published var audioIntervalMs: Int = 120

    // MARK: - Collapsible / Resizable Panels
    @Published var isDevicesExpanded = true
    @Published var isLogsExpanded = true

    @Published var devicesPanelHeight: CGFloat = 220
    @Published var logsPanelHeight: CGFloat = 200

    let worker: BluetoothWorker
    private var bag = Set<AnyCancellable>()

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(worker: BluetoothWorker) {
        self.worker = worker
        bind()
    }

    // MARK: - Bindings
    private func bind() {
        worker.$devices
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)

        worker.$logs
            .receive(on: DispatchQueue.main)
            .assign(to: &$logs)

        worker.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        worker.$isBluetoothReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isBluetoothReady)

        worker.$connectedName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard let self else { return }
                self.connectedName = name

                // Keep local stream toggle state in sync on connect/disconnect.
                if name == nil {
                    self.isGyroStreaming = false
                    self.isProximityStreaming = false
                    self.isEnvironmentStreaming = false
                    self.isAudioStreaming = false
                }
            }
            .store(in: &bag)

        worker.$canSend
            .receive(on: DispatchQueue.main)
            .assign(to: &$canSend)

        worker.$gyroSample
            .receive(on: DispatchQueue.main)
            .assign(to: &$gyroSample)

        worker.$lastGyroAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] d in
                guard let self else { return }
                self.lastGyroText = d.map { self.formatter.string(from: $0) } ?? "—"
            }
            .store(in: &bag)

        worker.$proximityValue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                guard let self else { return }
                self.proximityValue = v
                let pct = Int((Double(v) / 255.0 * 100.0).rounded())
                self.proximityPercentText = "\(pct)%"
            }
            .store(in: &bag)

        worker.$environmentSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                guard let self else { return }
                self.temperatureText = String(format: "%.1f ℃", s.temperatureC)
                self.humidityText = String(format: "%.1f %%", s.humidityRH)
                self.pressureText = String(format: "%.1f hPa", s.pressureHpa)
            }
            .store(in: &bag)

        worker.$audioSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] a in
                guard let self else { return }
                self.audioLevelText = "\(a.level)%"
                self.audioPeakText = "\(a.peak)"
                self.audioRmsText = String(format: "%.3f", a.rms)
            }
            .store(in: &bag)
    }

    // MARK: - BLE actions
    func search() { worker.search() }
    func stopSearch() { worker.stopSearch() }
    func connect(_ d: BluetoothWorker.Device) { worker.connect(d) }

    func disconnect() {
        stopAllStreams()
        worker.disconnect()
    }

    func ledOn() { worker.ledOn() }
    func ledOff() { worker.ledOff() }

    // MARK: - Stream toggles
    func toggleGyroStream(_ on: Bool) {
        isGyroStreaming = on
        guard canSend else { return }
        if on { worker.startGyroStreaming(intervalMs: gyroIntervalMs) }
        else { worker.stopGyroStreaming() }
    }

    func toggleProximityStream(_ on: Bool) {
        isProximityStreaming = on
        guard canSend else { return }
        if on { worker.startProximityStreaming(intervalMs: proximityIntervalMs) }
        else { worker.stopProximityStreaming() }
    }

    func toggleEnvironmentStream(_ on: Bool) {
        isEnvironmentStreaming = on
        guard canSend else { return }
        if on { worker.startEnvironmentStreaming(intervalMs: environmentIntervalMs) }
        else { worker.stopEnvironmentStreaming() }
    }

    func toggleAudioStream(_ on: Bool) {
        isAudioStreaming = on
        guard canSend else { return }
        if on { worker.startAudioStreaming(intervalMs: audioIntervalMs) }
        else { worker.stopAudioStreaming() }
    }

    func applyGyroInterval() {
        guard canSend, isGyroStreaming else { return }
        worker.stopGyroStreaming()
        worker.startGyroStreaming(intervalMs: gyroIntervalMs)
    }

    func applyProximityInterval() {
        guard canSend, isProximityStreaming else { return }
        worker.stopProximityStreaming()
        worker.startProximityStreaming(intervalMs: proximityIntervalMs)
    }

    func applyEnvironmentInterval() {
        guard canSend, isEnvironmentStreaming else { return }
        worker.stopEnvironmentStreaming()
        worker.startEnvironmentStreaming(intervalMs: environmentIntervalMs)
    }

    func applyAudioInterval() {
        guard canSend, isAudioStreaming else { return }
        worker.stopAudioStreaming()
        worker.startAudioStreaming(intervalMs: audioIntervalMs)
    }

    func stopAllStreams() {
        isGyroStreaming = false
        isProximityStreaming = false
        isEnvironmentStreaming = false
        isAudioStreaming = false

        worker.stopGyroStreaming()
        worker.stopProximityStreaming()
        worker.stopEnvironmentStreaming()
        worker.stopAudioStreaming()
    }
    // Fallback for builds where BluetoothWorker does not expose clearLogs().
    func clearLogsFallback() {
        logs.removeAll()
    }
}