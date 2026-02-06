//
//  DistanceViewModel.swift
//  BLEControlApp
//
//  Manages proximity stream data for distance visualization in the UI.
//

import Foundation
import Combine

final class DistanceViewModel: ObservableObject {
    @Published var rawValue: Int = 0
    @Published var normalized: Double = 0
    @Published var smoothNormalized: Double = 0
    @Published var distancePercentText: String = "0%"
    @Published var statusText: String = "No reading"
    @Published var lastUpdateText: String = "—"

    private let worker: BluetoothWorker
    private var bag = Set<AnyCancellable>()
    private let alpha = 0.14

    // If the current hardware/mounting is inverted, keep this as true.
    // true  => near objects appear as higher values in the UI
    // false => use worker scale directly
    private let invertScale = true

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
        worker.$proximityValue
            .combineLatest(worker.$proximityNormalized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] raw, norm in
                guard let self = self else { return }

                self.rawValue = raw

                // Safe clamp to 0...1
                let clamped = min(max(norm, 0), 1)

                // Invert scale to fix swapped near/far behavior
                let uiNorm = self.invertScale ? (1.0 - clamped) : clamped

                self.normalized = uiNorm
                self.smoothNormalized += (uiNorm - self.smoothNormalized) * self.alpha

                let pct = Int((self.smoothNormalized * 100).rounded())
                self.distancePercentText = "\(pct)%"

                // Low = far | High = near
                switch self.smoothNormalized {
                case ..<0.20:
                    self.statusText = "Far"
                case ..<0.60:
                    self.statusText = "Medium"
                default:
                    self.statusText = "Very close"
                }
            }
            .store(in: &bag)

        worker.$lastProximityAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] d in
                guard let self = self else { return }
                self.lastUpdateText = d.map { self.formatter.string(from: $0) } ?? "—"
            }
            .store(in: &bag)
    }

    func startStreaming() { worker.startProximityStreaming() }
    func stopStreaming() { worker.stopProximityStreaming() }
}