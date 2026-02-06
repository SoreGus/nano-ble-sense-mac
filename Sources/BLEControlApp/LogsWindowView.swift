//
//  LogsWindowView.swift
//  BLEControlApp
//
//  Created by Gustavo on 2026-02-06.
//
//  Purpose:
//  Presents the application logs in a dedicated window, with support for
//  clearing visible entries from the dashboard view model.
//
import SwiftUI

struct LogsWindowView: View {
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