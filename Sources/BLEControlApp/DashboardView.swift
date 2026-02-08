//
//  DashboardView.swift
//  BLEControlApp
//
//  Main dashboard screen for BLE monitoring and control.
//  Provides quick stats, stream controls, and navigation to specialized views.
//
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @EnvironmentObject var gyroVM: GiroscopeViewModel
    @EnvironmentObject var distanceVM: DistanceViewModel
    @EnvironmentObject var environmentVM: EnvironmentViewModel
    @EnvironmentObject var audioVM: EnvironmentAudioViewModel

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #else
    @State private var showDevicesSheet = false
    @State private var showLogsSheet = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                topBar
                statsGrid
                streamsAndNavigation
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [
                        {
                            #if os(macOS)
                            return Color(nsColor: .windowBackgroundColor)
                            #else
                            return Color(uiColor: .systemBackground)
                            #endif
                        }(),
                        Color.gray.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("BLE Dashboard")
        }
#if !os(macOS)
        .sheet(isPresented: $showDevicesSheet) {
            NavigationStack {
                DevicesSheetView()
                    .environmentObject(vm)
                    .navigationTitle("Devices")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showDevicesSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showLogsSheet) {
            NavigationStack {
                LogsSheetView()
                    .environmentObject(vm)
                    .navigationTitle("Logs")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showLogsSheet = false }
                        }
                    }
            }
        }
#endif
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 10) {
            #if os(macOS)
            Button {
                openWindow(id: "devices-window")
            } label: {
                Label("Devices", systemImage: "dot.radiowaves.left.and.right")
            }

            Button {
                openWindow(id: "logs-window")
            } label: {
                Label("Logs", systemImage: "text.alignleft")
            }
            #else
            Button {
                showDevicesSheet = true
            } label: {
                Label("Devices", systemImage: "dot.radiowaves.left.and.right")
            }

            Button {
                showLogsSheet = true
            } label: {
                Label("Logs", systemImage: "text.alignleft")
            }
            #endif

            Divider().frame(height: 20)

            Button("LED ON") { vm.ledOn() }
                .disabled(!vm.canSend)

            Button("LED OFF") { vm.ledOff() }
                .disabled(!vm.canSend)

            Button(role: .destructive) {
                vm.stopAllStreams()
            } label: {
                Label("Stop Streams", systemImage: "pause.circle")
            }
            .disabled(!vm.canSend)

            Spacer()

            connectionPill

            Button("Disconnect") { vm.disconnect() }
                .disabled(vm.connectedName == nil)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var connectionPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.connectedName == nil ? Color.orange : Color.green)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.connectedName == nil ? "Not connected" : "Connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(vm.connectedName == nil ? .orange : .green)

                Text(vm.connectedName ?? "Select a device in Devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(vm.connectedName == nil ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(vm.connectedName == nil ? Color.orange.opacity(0.35) : Color.green.opacity(0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 180), spacing: 10),
                GridItem(.flexible(minimum: 180), spacing: 10),
                GridItem(.flexible(minimum: 180), spacing: 10),
                GridItem(.flexible(minimum: 180), spacing: 10)
            ],
            spacing: 10
        ) {
            statCard("Gyro X", value: String(format: "%.3f", vm.gyroSample.x), icon: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            statCard("Gyro Y", value: String(format: "%.3f", vm.gyroSample.y), icon: "arrow.up.and.down.righttriangle.up.righttriangle.down")
            statCard("Gyro Z", value: String(format: "%.3f", vm.gyroSample.z), icon: "gyroscope")
            statCard("Last Gyro", value: vm.lastGyroText, icon: "clock")

            statCard("Proximity", value: "\(vm.proximityValue) (\(vm.proximityPercentText))", icon: "dot.radiowaves.left.and.right")
            statCard("Temperature", value: vm.temperatureText, icon: "thermometer")
            statCard("Humidity", value: vm.humidityText, icon: "humidity.fill")
            statCard("Pressure", value: vm.pressureText, icon: "barometer")

            statCard("Audio Level", value: vm.audioLevelText, icon: "waveform")
            statCard("Audio Peak", value: vm.audioPeakText, icon: "waveform.path.ecg")
            statCard("Audio RMS", value: vm.audioRmsText, icon: "chart.bar")
            statCard("Bluetooth", value: vm.isBluetoothReady ? "Ready" : "Off", icon: "bolt.horizontal.circle")
        }
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bottom area

    private var streamsAndNavigation: some View {
        HStack(alignment: .top, spacing: 12) {
            streamsPanel
            navigationPanel
        }
    }

    private var streamsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stream Control")
                .font(.headline)

            streamRow(title: "Gyroscope",
                      isOn: $vm.isGyroStreaming,
                      interval: $vm.gyroIntervalMs,
                      toggleAction: vm.toggleGyroStream,
                      applyAction: vm.applyGyroInterval)

            streamRow(title: "Proximity",
                      isOn: $vm.isProximityStreaming,
                      interval: $vm.proximityIntervalMs,
                      toggleAction: vm.toggleProximityStream,
                      applyAction: vm.applyProximityInterval)

            streamRow(title: "Environment",
                      isOn: $vm.isEnvironmentStreaming,
                      interval: $vm.environmentIntervalMs,
                      toggleAction: vm.toggleEnvironmentStream,
                      applyAction: vm.applyEnvironmentInterval)

            streamRow(title: "Audio",
                      isOn: $vm.isAudioStreaming,
                      interval: $vm.audioIntervalMs,
                      toggleAction: vm.toggleAudioStream,
                      applyAction: vm.applyAudioInterval)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func streamRow(
        title: String,
        isOn: Binding<Bool>,
        interval: Binding<Int>,
        toggleAction: @escaping (Bool) -> Void,
        applyAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 110, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    toggleAction(newValue)
                }
                .disabled(!vm.canSend)

            Stepper(value: interval, in: 40...2000, step: 10) {
                Text("\(interval.wrappedValue) ms")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90, alignment: .trailing)
            }
            .onChange(of: interval.wrappedValue) { _, _ in applyAction() }
            .disabled(!vm.canSend)

            Spacer()
        }
    }

    private var navigationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Views")
                .font(.headline)

            NavigationLink { GiroscopeView().environmentObject(gyroVM) } label: {
                navCard("Gyroscope", "gyroscope", subtitle: "Detailed gyroscope visualization")
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)

            NavigationLink { DistanceView().environmentObject(distanceVM) } label: {
                navCard("Distance", "dot.radiowaves.left.and.right", subtitle: "Proximity reading and trend")
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)

            NavigationLink { EnvironmentView().environmentObject(environmentVM) } label: {
                navCard("Environment", "thermometer.sun", subtitle: "Temperature, humidity, and pressure")
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)

            NavigationLink { EnvironmentAudioView().environmentObject(audioVM) } label: {
                navCard("Audio", "waveform", subtitle: "Ambient sound intensity")
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func navCard(_ title: String, _ icon: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if !os(macOS)
private struct DevicesSheetView: View {
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

private struct LogsSheetView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Logs")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Clear") {
                    vm.clearLogsFallback()
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(vm.logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
    }
}
#endif