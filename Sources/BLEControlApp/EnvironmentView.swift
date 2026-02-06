//
//  EnvironmentView.swift
//  BLEControlApp
//
//  Created by Gustavo on 2026-02-06.
//

import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var vm: EnvironmentViewModel

    @State private var animatePulse = false
    @State private var appear = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: appear)

                    topMetricsGrid
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 12)
                        .animation(.easeOut(duration: 0.45).delay(0.05), value: appear)

                    comfortAndPressureSection
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 14)
                        .animation(.easeOut(duration: 0.55).delay(0.10), value: appear)

                    footer
                        .opacity(appear ? 1 : 0)
                        .animation(.easeOut(duration: 0.65).delay(0.15), value: appear)
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Environment")
        .onAppear {
            appear = true
            animatePulse = true
            vm.startStreaming()
        }
        .onDisappear {
            vm.stopStreaming()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.22))
                    .frame(width: 54, height: 54)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Environment Monitor")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(vm.statusText)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            infoPill(title: "Updated", value: vm.lastUpdateText, icon: "clock")
        }
    }

    private var topMetricsGrid: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "Temperature",
                value: String(format: "%.1f ℃", vm.smoothTemperatureC),
                subtitle: "Ambient",
                icon: "thermometer.medium",
                tint: .orange
            )

            metricCard(
                title: "Humidity",
                value: String(format: "%.1f %%", vm.smoothHumidityRH),
                subtitle: "Relative",
                icon: "humidity.fill",
                tint: .blue
            )

            metricCard(
                title: "Pressure",
                value: String(format: "%.2f hPa", vm.smoothPressureHpa),
                subtitle: String(format: "%.2f mmHg", vm.pressureMmHg),
                icon: "gauge.with.dots.needle.33percent",
                tint: .cyan
            )
        }
    }

    private var comfortAndPressureSection: some View {
        HStack(alignment: .top, spacing: 12) {
            comfortCard
            pressureCard
        }
    }

    private var comfortCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Comfort Index", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text("\(Int((vm.comfortScore * 100).rounded()))%")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.20))
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 14)
                            .foregroundStyle(Color.white.opacity(0.14))

                        Circle()
                            .trim(from: 0, to: max(0.02, vm.comfortScore))
                            .stroke(
                                AngularGradient(
                                    colors: [.green, .yellow, .orange, .red, .green],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.40, dampingFraction: 0.85), value: vm.comfortScore)

                        Circle()
                            .stroke(statusColor.opacity(0.45), lineWidth: 2)
                            .scaleEffect(animatePulse ? 1.06 : 0.94)
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animatePulse)

                        VStack(spacing: 2) {
                            Text("\(Int((vm.comfortScore * 100).rounded()))")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text("score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)

                    VStack(alignment: .leading, spacing: 10) {
                        comfortLegend(color: .green, text: "Comfortable")
                        comfortLegend(color: .yellow, text: "Acceptable")
                        comfortLegend(color: .orange, text: "Attention")
                        comfortLegend(color: .red, text: "Uncomfortable")

                        Divider().padding(.vertical, 2)

                        Text("Based on smoothed temperature and humidity.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                comfortLinearBar
            }
        }
        .frame(maxWidth: .infinity, minHeight: 290)
    }

    private var comfortLinearBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comfort Progress")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

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
                        .frame(
                            width: max(10, geo.size.width * max(0.02, vm.comfortScore)),
                            height: 14
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.80), value: vm.comfortScore)
                }
            }
            .frame(height: 14)
        }
    }

    private var pressureCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "barometer")
                        .font(.headline)
                    Text("Pressure Trend")
                        .font(.headline)
                    Spacer()
                    Text(vm.pressureTrendText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", vm.smoothPressureHpa))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("hPa")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "%.2f mmHg", vm.pressureMmHg))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                pressureGauge
            }
        }
        .frame(maxWidth: .infinity, minHeight: 290)
    }

    private var pressureGauge: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let minP = 980.0
                let maxP = 1040.0
                let clamped = min(max(vm.smoothPressureHpa, minP), maxP)
                let ratio = (clamped - minP) / (maxP - minP)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 12)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.mint, .cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * ratio), height: 12)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: vm.smoothPressureHpa)

                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 16, height: 16)
                        .offset(x: max(0, geo.size.width * ratio - 8))
                        .shadow(radius: 5, y: 2)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: vm.smoothPressureHpa)
                }
            }
            .frame(height: 16)

            HStack {
                Text("980")
                Spacer()
                Text("1013")
                Spacer()
                Text("1040")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Label("Live stream active", systemImage: "dot.radiowaves.left.and.right")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Last reading: \(vm.lastUpdateText)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(tint)

                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()
                }

                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 138)
    }

    private func infoPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
    }

    private func comfortLegend(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                statusColor.opacity(0.12),
                Color.blue.opacity(0.08),
                Color.mint.opacity(0.08),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var statusColor: Color {
        switch vm.comfortScore {
        case 0.85...: return .green
        case 0.65..<0.85: return .yellow
        case 0.40..<0.65: return .orange
        default: return .red
        }
    }
}