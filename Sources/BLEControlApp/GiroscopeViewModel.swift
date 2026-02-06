//
//  GiroscopeViewModel.swift
//  BLEControlApp
//
//  Handles gyroscope stream smoothing, level detection,
//  and formatted last-update time for the gyroscope screen.
//

import Foundation
import Combine

final class GiroscopeViewModel: ObservableObject {
    @Published var displayX: Double = 0
    @Published var displayY: Double = 0
    @Published var displayZ: Double = 0
    @Published var isLevel: Bool = true
    @Published var levelProgress: Double = 1.0
    @Published var lastUpdateText: String = "—"

    private let worker: BluetoothWorker
    private var bag = Set<AnyCancellable>()
    private let alpha = 0.18
    private let levelThreshold = 0.10
    private let maxVisualTilt = 1.80
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
        worker.$gyroSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                guard let self = self else { return }
                self.displayX = self.displayX + (s.x - self.displayX) * self.alpha
                self.displayY = self.displayY + (s.y - self.displayY) * self.alpha
                self.displayZ = self.displayZ + (s.z - self.displayZ) * self.alpha

                let magnitude = sqrt(self.displayX * self.displayX + self.displayY * self.displayY)
                self.isLevel = magnitude <= self.levelThreshold
                let normalized = min(max(magnitude / self.maxVisualTilt, 0), 1)
                self.levelProgress = 1.0 - normalized
            }
            .store(in: &bag)

        worker.$lastGyroAt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                guard let self = self else { return }
                self.lastUpdateText = date.map { self.formatter.string(from: $0) } ?? "—"
            }
            .store(in: &bag)
    }

    func startStreaming() { worker.startGyroStreaming() }
    func stopStreaming() { worker.stopGyroStreaming() }
}
