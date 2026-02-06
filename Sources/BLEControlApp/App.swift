//
//  App.swift
//  BLEControlApp
//
//  App entry point and window/command configuration.
//
import SwiftUI

@main
struct BLEControlApp: App {
    @StateObject private var worker: BluetoothWorker
    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var giroscopeVM: GiroscopeViewModel
    @StateObject private var distanceVM: DistanceViewModel
    @StateObject private var environmentVM: EnvironmentViewModel
    @StateObject private var environmentAudioVM: EnvironmentAudioViewModel

    init() {
        let w = BluetoothWorker()
        _worker = StateObject(wrappedValue: w)
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(worker: w))
        _giroscopeVM = StateObject(wrappedValue: GiroscopeViewModel(worker: w))
        _distanceVM = StateObject(wrappedValue: DistanceViewModel(worker: w))
        _environmentVM = StateObject(wrappedValue: EnvironmentViewModel(worker: w))
        _environmentAudioVM = StateObject(wrappedValue: EnvironmentAudioViewModel(worker: w))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(worker)
                .environmentObject(dashboardVM)
                .environmentObject(giroscopeVM)
                .environmentObject(distanceVM)
                .environmentObject(environmentVM)
                .environmentObject(environmentAudioVM)
        }
        .commands {
            ToolsCommands()
        }

        WindowGroup("Devices", id: "devices-window") {
            DevicesWindowView()
                .environmentObject(dashboardVM)
        }
        .defaultSize(width: 760, height: 420)

        WindowGroup("Logs", id: "logs-window") {
            LogsWindowView()
                .environmentObject(dashboardVM)
        }
        .defaultSize(width: 900, height: 520)
    }
}

struct ToolsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Tools") {
            Button("Devices") {
                openWindow(id: "devices-window")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Logs") {
                openWindow(id: "logs-window")
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}