//
//  DistanceView.swift
//  BLEControlApp
//
//  Created by Gustavo on 2026-02-06.
//

import SwiftUI

struct DistanceView: View {
    @EnvironmentObject var vm: DistanceViewModel
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Proximity").font(.system(size: 30, weight: .bold, design: .rounded))
                Text(vm.statusText).font(.headline).foregroundStyle(colorForLevel())
            }

            ZStack {
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            .frame(width: CGFloat(70 + i*55), height: CGFloat(70 + i*55))
                    }
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 290, height: 1)
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 290)
                }

                Circle()
                    .fill(RadialGradient(colors: [colorForLevel().opacity(0.9), colorForLevel().opacity(0.12)], center: .center, startRadius: 6, endRadius: 180))
                    .frame(width: 240, height: 240)
                    .scaleEffect((0.22 + vm.smoothNormalized * 0.95) * (pulse ? 1.04 : 0.96))
                    .shadow(color: colorForLevel().opacity(0.45), radius: 24)
                    .animation(.spring(response: 0.35, dampingFraction: 0.76), value: vm.smoothNormalized)

                Circle().fill(Color.white).frame(width: 9, height: 9).shadow(radius: 2)

                VStack(spacing: 4) {
                    Text(vm.distancePercentText)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("intensity").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .frame(width: 330, height: 330)

            HStack(spacing: 12) {
                statCard("RAW", "\(vm.rawValue)")
                statCard("Level", vm.distancePercentText)
                statCard("Status", vm.statusText)
            }

            Text("Last reading: \(vm.lastUpdateText)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(20)
        .navigationTitle("Distance Sensor")
        .onAppear {
            vm.startStreaming()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onDisappear { vm.stopStreaming() }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.body, design: .rounded).weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorForLevel() -> Color {
        if vm.smoothNormalized < 0.2 { return .green }
        if vm.smoothNormalized < 0.6 { return .yellow }
        return .red
    }
}
