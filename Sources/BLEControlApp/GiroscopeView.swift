//
//  GiroscopeView.swift
//  BLEControlApp
//
//  Advanced gyroscope dashboard with animated level gauge,
//  real-time axis metrics, and streaming lifecycle handling.
//

import SwiftUI

struct GiroscopeView: View {
    @EnvironmentObject var vm: GiroscopeViewModel

    private let gaugeSize: CGFloat = 340
    private let maxVisualTilt: Double = 1.80

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

                    gaugeCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 12)
                        .animation(.easeOut(duration: 0.45).delay(0.05), value: appear)

                    bottomCards
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 12)
                        .animation(.easeOut(duration: 0.55).delay(0.10), value: appear)
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Gyroscope")
        .onAppear {
            appear = true
            pulse = true
            vm.startStreaming()
        }
        .onDisappear {
            vm.stopStreaming()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 54, height: 54)

                Image(systemName: "gyroscope")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Gyroscope Level")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(vm.isLevel ? "LEVEL OK" : "ADJUST THE PLANE")
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }
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

    // MARK: - Gauge Card

    private var gaugeCard: some View {
        glassCard {
            VStack(spacing: 16) {
                ZStack {
                    // base
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .green.opacity(0.20),
                                    .yellow.opacity(0.16),
                                    .orange.opacity(0.16),
                                    .red.opacity(0.18)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: gaugeSize / 2
                            )
                        )

                    // rings
                    Circle().stroke(Color.white.opacity(0.26), lineWidth: 1.2)
                    Circle().inset(by: gaugeSize * 0.14).stroke(Color.white.opacity(0.20), lineWidth: 1)
                    Circle().inset(by: gaugeSize * 0.28).stroke(Color.white.opacity(0.16), lineWidth: 1)
                    Circle().inset(by: gaugeSize * 0.40).stroke(Color.white.opacity(0.12), lineWidth: 1)

                    // crosshair
                    Rectangle()
                        .fill(Color.white.opacity(0.17))
                        .frame(width: gaugeSize * 0.84, height: 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.17))
                        .frame(width: 1, height: gaugeSize * 0.84)

                    // center
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 8, height: 8)

                    // pulse ring
                    Circle()
                        .stroke(statusColor.opacity(0.45), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.28 : 0.9)
                        .opacity(pulse ? 0.15 : 0.55)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    // bubble
                    Circle()
                        .fill(statusColor)
                        .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
                        .shadow(color: statusColor.opacity(0.45), radius: 12, y: 4)
                        .frame(width: 30, height: 30)
                        .offset(x: bubbleOffset().x, y: bubbleOffset().y)
                        .animation(.interpolatingSpring(stiffness: 160, damping: 18), value: vm.displayX)
                        .animation(.interpolatingSpring(stiffness: 160, damping: 18), value: vm.displayY)
                }
                .frame(width: gaugeSize, height: gaugeSize)

                tiltBar
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity)
    }

    private var tiltBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tilt stability")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((vm.levelProgress * 100).rounded()))%")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.16))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 14)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * max(0.02, vm.levelProgress)), height: 14)
                        .animation(.spring(response: 0.35, dampingFraction: 0.84), value: vm.levelProgress)
                }
            }
            .frame(height: 14)
        }
    }

    // MARK: - Bottom

    private var bottomCards: some View {
        HStack(spacing: 12) {
            axisCard(title: "X", value: vm.displayX, icon: "arrow.left.and.right")
            axisCard(title: "Y", value: vm.displayY, icon: "arrow.up.and.down")
            axisCard(title: "Z", value: vm.displayZ, icon: "move.3d")
        }
    }

    private func axisCard(title: String, value: Double, icon: String) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                Text(String(format: "%.3f", value))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("rad/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        vm.isLevel ? .green : .red
    }

    private var background: some View {
        LinearGradient(
            colors: [
                statusColor.opacity(0.10),
                .blue.opacity(0.08),
                .indigo.opacity(0.06),
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

    private func bubbleOffset() -> (x: CGFloat, y: CGFloat) {
        let radius = (gaugeSize / 2) - 22
        let nx = min(max(vm.displayX / maxVisualTilt, -1), 1)
        let ny = min(max(vm.displayY / maxVisualTilt, -1), 1)

        var x = CGFloat(nx) * radius
        var y = CGFloat(-ny) * radius

        let d = sqrt(x * x + y * y)
        if d > radius {
            let k = radius / d
            x *= k
            y *= k
        }
        return (x, y)
    }
}