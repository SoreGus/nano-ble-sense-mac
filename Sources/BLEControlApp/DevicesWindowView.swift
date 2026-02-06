//
//  DevicesWindowView.swift
//  BLEControlApp
//
//  Displays BLE NUS devices, scan controls, and connection state.
//  This view is presented as a dedicated tools window.
//

import SwiftUI

struct DevicesWindowView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            header
            controls
            devicesList
        }
        .padding(12)
        .onAppear {
            if vm.isBluetoothReady && !vm.isScanning {
                vm.search()
            }
        }
        .onDisappear {
            if vm.isScanning {
                vm.stopSearch()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("BLE Devices (NUS)")
                .font(.title3.weight(.semibold))

            Spacer()

            connectionPill
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.connectedName == nil ? Color.orange : Color.green)
                .frame(width: 8, height: 8)

            Text(vm.connectedName == nil ? "Not connected" : (vm.connectedName ?? "Connected"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(vm.connectedName == nil ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(vm.connectedName == nil ? Color.orange.opacity(0.35) : Color.green.opacity(0.35), lineWidth: 1)
        )
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                vm.search()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .disabled(!vm.isBluetoothReady || vm.isScanning)

            Button {
                vm.stopSearch()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!vm.isScanning)

            Spacer()

            Text(vm.isScanning ? "Scanning..." : "Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var devicesList: some View {
        List(vm.devices) { device in
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.body)

                    Text(device.id.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text("RSSI \(device.rssi)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Connect") {
                    vm.stopSearch()
                    vm.connect(device)
                    dismiss()
                }
            }
            .padding(.vertical, 2)
        }
    }
}