/*
 File: EnvironmentViewModel.swift
 Project: BLEControlApp
 Description: View model responsible for environment metrics (temperature, humidity, pressure), smoothing, comfort scoring, pressure trend detection, and stream lifecycle control.
*/

import Foundation
import Combine

final class EnvironmentViewModel: ObservableObject {
    @Published var temperatureC: Double = 0
    @Published var humidityRH: Double = 0
    @Published var pressureHpa: Double = 0

    @Published var smoothTemperatureC: Double = 0
    @Published var smoothHumidityRH: Double = 0
    @Published var smoothPressureHpa: Double = 0

    @Published var comfortScore: Double = 0
    @Published var statusText: String = "No reading"
    @Published var pressureTrendText: String = "Stable"
    @Published var lastUpdateText: String = "—"

    private let worker: BluetoothWorker
    private var bag = Set<AnyCancellable>()
    private let alpha = 0.15
    private var previousSmoothPressure: Double = 0

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(worker: BluetoothWorker) {
        self.worker = worker
        bind()
    }

    private func bind() {
        worker.$environmentSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                guard let self else { return }

                self.temperatureC = s.temperatureC
                self.humidityRH = s.humidityRH
                self.pressureHpa = s.pressureHpa

                self.smoothTemperatureC += (s.temperatureC - self.smoothTemperatureC) * self.alpha
                self.smoothHumidityRH += (s.humidityRH - self.smoothHumidityRH) * self.alpha
                self.smoothPressureHpa += (s.pressureHpa - self.smoothPressureHpa) * self.alpha

                self.comfortScore = self.computeComfort(
                    tempC: self.smoothTemperatureC,
                    humidity: self.smoothHumidityRH
                )
                self.statusText = self.computeStatus(score: self.comfortScore)
                self.pressureTrendText = self.computePressureTrend(current: self.smoothPressureHpa)
            }
            .store(in: &bag)

        worker.$lastEnvironmentAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] d in
                guard let self else { return }
                self.lastUpdateText = d.map { self.formatter.string(from: $0) } ?? "—"
            }
            .store(in: &bag)
    }

    func startStreaming() { worker.startEnvironmentStreaming() }
    func stopStreaming() { worker.stopEnvironmentStreaming() }

    var pressureMmHg: Double {
        smoothPressureHpa * 0.750061683
    }

    private func computeComfort(tempC: Double, humidity: Double) -> Double {
        let tempPenalty = min(abs(tempC - 23.0) / 12.0, 1.0)
        let humPenalty = min(abs(humidity - 50.0) / 50.0, 1.0)
        return max(0, 1.0 - (0.58 * tempPenalty + 0.42 * humPenalty))
    }

    private func computeStatus(score: Double) -> String {
        switch score {
        case 0.85...: return "Comfortable"
        case 0.65..<0.85: return "Acceptable"
        case 0.40..<0.65: return "Attention"
        default: return "Uncomfortable"
        }
    }

    private func computePressureTrend(current: Double) -> String {
        defer { previousSmoothPressure = current }

        guard previousSmoothPressure > 0 else { return "Stable" }
        let delta = current - previousSmoothPressure

        if delta > 0.12 { return "Rising" }
        if delta < -0.12 { return "Falling" }
        return "Stable"
    }
}