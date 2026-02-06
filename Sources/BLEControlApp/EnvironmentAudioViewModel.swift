//
//  EnvironmentAudioViewModel.swift
//  BLEControlApp
//
//  Created for BLE audio environment monitoring.
//

import Foundation
import Combine

final class EnvironmentAudioViewModel: ObservableObject {
    @Published var level: Int = 0
    @Published var rms: Double = 0
    @Published var peak: Int = 0
    @Published var smoothLevel: Double = 0
    @Published var smoothRms: Double = 0
    @Published var displayLevel: Double = 0
    @Published var statusText: String = "Silent"
    @Published var lastUpdateText: String = "—"

    private let worker: BluetoothWorker
    private var bag = Set<AnyCancellable>()
    private let alpha = 0.22

    // Revised calibration (stronger at low levels):
    // - increases sensitivity for low signals
    // - keeps progression in the mid range
    // - still preserves control near the top
    private let inputGain = 3.2
    private let gamma = 0.90
    private let noiseFloor = 0.008

    // Fusion weights (peak + level)
    private let peakWeight = 0.62
    private let levelWeight = 0.38

    // Mathematical boost for the initial range (x close to 0)
    // lowBoost = x + a*(x - x^2), peaking at x=0.5
    private let lowBoostStrength = 1.05

    // Soft top compression to avoid early saturation
    private let topKneeStart = 0.86
    private let topKneeRatio = 0.65
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
        worker.$audioSample.receive(on: DispatchQueue.main).sink { [weak self] s in
            guard let self else { return }
            level = s.level
            rms = s.rms
            peak = s.peak

            // Initial pre-boost + strong PEAK usage to avoid zeroing useful signals
            let rawLevel = min(max(Double(s.level), 0.0), 100.0)
            let preboostLevel = min(100.0, pow(rawLevel / 100.0, 0.78) * 100.0)
            smoothLevel += (preboostLevel - smoothLevel) * alpha
            smoothRms += (s.rms - smoothRms) * alpha

            // Combine normalized PEAK (0...32767) with smoothed level.
            let peakNorm = min(max(Double(s.peak) / 32767.0, 0.0), 1.0)
            let levelNorm = min(max(smoothLevel / 100.0, 0.0), 1.0)
            let combined = min(1.0, peakNorm * peakWeight + levelNorm * levelWeight)

            // Remove floor and apply gain
            let denoised = max(0.0, (combined - noiseFloor) / max(1e-9, (1.0 - noiseFloor)))
            var x = min(1.0, denoised * inputGain)

            // Base curve
            x = pow(x, gamma)

            // Initial boost (more weight for lower values)
            // f(x) = x + a*(x - x^2)
            // - preserves 0 and 1
            // - increases more in the low/low-mid range
            let boosted = x + lowBoostStrength * (x - x * x)
            x = min(1.0, max(0.0, boosted))

            // Soft-knee at the top: compress only above topKneeStart
            if x > topKneeStart {
                let over = x - topKneeStart
                x = topKneeStart + over * topKneeRatio
            }

            displayLevel = min(100.0, max(0.0, x * 100.0))

            statusText = classify(level: displayLevel)
        }.store(in: &bag)

        worker.$lastAudioAt.receive(on: DispatchQueue.main).sink { [weak self] d in
            guard let self else { return }
            lastUpdateText = d.map { self.formatter.string(from: $0) } ?? "—"
        }.store(in: &bag)
    }

    func startStreaming() { worker.startAudioStreaming() }
    func stopStreaming() { worker.stopAudioStreaming() }


    private func classify(level: Double) -> String {
        switch level {
        case ..<12:  return "Near silent"
        case ..<24:  return "Low"
        case ..<38:  return "Moderate-"
        case ..<54:  return "Moderate"
        case ..<70:  return "Moderate+"
        case ..<86:  return "High"
        default:     return "Very high"
        }
    }
}
