import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @Binding var tab: RootView.Tab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    routerCard
                    statsRow
                    scanButton
                    if state.isScanning { scanProgress }
                    recentDevicesCard
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("JetWIFI")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Router status
    private var routerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "wifi.router.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accentGradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.config.isConfigured ? state.config.kind.displayName + " router" : "No router connected")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(state.config.isConfigured ? (state.config.host.isEmpty ? "Configured" : state.config.host)
                                                    : "Add yours in Settings to manage access")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Circle()
                    .fill(state.config.isConfigured ? Theme.success : Theme.textTertiary)
                    .frame(width: 10, height: 10)
            }

            if state.config.isConfigured && !state.config.kind.canAttemptRestrictions {
                Text(state.config.kind.supportSummary)
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
            }
        }
        .cardStyle()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(state.onlineCount)", label: "Online", icon: "dot.radiowaves.left.and.right", color: Theme.cyan)
            StatTile(value: "\(state.devices.count)", label: "Known", icon: "externaldrive.fill", color: Theme.accent)
            StatTile(value: "\(state.restrictedDevices.count)", label: "Blocked", icon: "hand.raised.fill", color: Theme.danger)
        }
    }

    private var scanButton: some View {
        Button {
            Task { await state.scan() }
        } label: {
            HStack {
                Image(systemName: state.isScanning ? "antenna.radiowaves.left.and.right" : "arrow.triangle.2.circlepath")
                Text(state.isScanning ? "Scanning…" : "Scan network")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.black)
        }
        .disabled(state.isScanning)
        .opacity(state.isScanning ? 0.7 : 1)
    }

    private var scanProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: state.scanProgress)
                .tint(Theme.cyan)
            Text(state.scanPhase)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle()
    }

    private var recentDevicesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Devices")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("See all") { tab = .devices }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.cyan)
            }

            if state.devices.isEmpty {
                EmptyHint(icon: "wifi", title: "No devices yet",
                          message: "Tap Scan network to discover everything on your Wi-Fi.")
            } else {
                ForEach(state.devices.prefix(6)) { device in
                    NavigationLink(value: device.id) {
                        DeviceRow(device: device)
                    }
                    if device.id != state.devices.prefix(6).last?.id {
                        Divider().overlay(Theme.cardStroke)
                    }
                }
            }
        }
        .cardStyle()
        .navigationDestination(for: String.self) { id in
            if let device = state.devices.first(where: { $0.id == id }) {
                DeviceDetailView(deviceID: device.id)
            }
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.textTertiary)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
