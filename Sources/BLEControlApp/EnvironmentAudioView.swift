//
//  EnvironmentAudioView.swift
//  BLEControlApp
//
//  Created by Gustavo on 2026-02-06.
//

import SwiftUI

struct EnvironmentAudioView: View {
    @EnvironmentObject var vm: EnvironmentAudioViewModel

    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: appear)

                    mainCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 12)
                        .animation(.easeOut(duration: 0.45).delay(0.04), value: appear)

                    bottomRow
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 12)
                        .animation(.easeOut(duration: 0.55).delay(0.08), value: appear)
                }
                .padding(20)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Audio")
        .onAppear {
            appear = true
            pulse = true
            vm.startStreaming()
        }
        .onDisappear {
            vm.stopStreaming()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(levelColor.opacity(0.16))
                    .frame(width: 54, height: 54)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(levelColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Environment Audio")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(vm.statusText)
                    .font(.headline)
                    .foregroundStyle(levelColor)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "clock")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Last reading")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(vm.lastUpdateText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
        }
    }

    private var mainCard: some View {
        glassCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [levelColor.opacity(0.42), levelColor.opacity(0.04)],
                                center: .center,
                                startRadius: 8,
                                endRadius: 180
                            )
                        )
                        .frame(width: 320, height: 320)
                        .scaleEffect(0.74 + vm.smoothRms * 0.95)
                        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: vm.smoothRms)

                    Circle()
                        .stroke(levelColor.opacity(0.45), lineWidth: 2.2)
                        .frame(width: 190, height: 190)
                        .scaleEffect(pulse ? 1.17 : 0.88)
                        .opacity(pulse ? 0.14 : 0.55)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 190, height: 190)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )

                    VStack(spacing: 4) {
                        Text("\(Int(vm.smoothLevel.rounded()))%")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .monospacedDigit()

                        Text("Sound level")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                loudnessBar
                    .frame(maxWidth: 560)
            }
            .padding(8)
        }
    }

    private var loudnessBar: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Loudness", systemImage: "waveform.path.ecg")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(vm.smoothLevel.rounded()))%")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(levelColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 16)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: barGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(14, geo.size.width * min(max(vm.smoothLevel / 100.0, 0.0), 1.0)),
                            height: 16
                        )
                        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: vm.smoothLevel)
                }
            }
            .frame(height: 16)

            HStack {
                Text("Low")
                Spacer()
                Text("Medium")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "RMS",
                value: String(format: "%.3f", vm.smoothRms),
                icon: "waveform.path"
            )
            statCard(
                title: "PEAK",
                value: "\(vm.peak)",
                icon: "arrow.up.right.circle.fill"
            )
            statCard(
                title: "Level",
                value: "\(vm.level)%",
                icon: "gauge.medium"
            )
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var levelColor: Color {
        switch vm.smoothLevel {
        case ..<6:  return Color(red: 0.20, green: 0.84, blue: 0.56)
        case ..<14: return Color(red: 0.16, green: 0.82, blue: 0.78)
        case ..<26: return Color(red: 0.36, green: 0.74, blue: 0.98)
        case ..<40: return Color(red: 0.58, green: 0.60, blue: 0.98)
        case ..<55: return Color(red: 0.98, green: 0.78, blue: 0.33)
        case ..<72: return Color(red: 0.98, green: 0.60, blue: 0.29)
        case ..<86: return Color(red: 0.96, green: 0.41, blue: 0.41)
        default:    return Color(red: 0.86, green: 0.24, blue: 0.42)
        }
    }

    private var barGradientColors: [Color] {
        [
            Color(red: 0.20, green: 0.84, blue: 0.56),
            Color(red: 0.16, green: 0.82, blue: 0.78),
            Color(red: 0.36, green: 0.74, blue: 0.98),
            Color(red: 0.58, green: 0.60, blue: 0.98),
            Color(red: 0.98, green: 0.78, blue: 0.33),
            Color(red: 0.98, green: 0.60, blue: 0.29),
            Color(red: 0.96, green: 0.41, blue: 0.41),
            Color(red: 0.86, green: 0.24, blue: 0.42)
        ]
    }

    private var background: some View {
        LinearGradient(
            colors: [
                levelColor.opacity(0.14),
                Color(red: 0.10, green: 0.12, blue: 0.24).opacity(0.22),
                Color(red: 0.08, green: 0.22, blue: 0.26).opacity(0.16),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func glassCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            content()
                .padding(14)
        }
    }
}