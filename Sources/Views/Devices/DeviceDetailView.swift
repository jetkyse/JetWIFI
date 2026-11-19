import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject var state: AppState
    let deviceID: String

    @State private var working = false
    @State private var editingName = false
    @State private var draftName = ""
    @State private var confirmRestrict = false

    private var device: Device? { state.devices.first { $0.id == deviceID } }

    var body: some View {
        ScrollView {
            if let device {
                VStack(spacing: 16) {
                    header(device)
                    infoCard(device)
                    accessCard(device)
                }
                .padding(16)
            } else {
                EmptyHint(icon: "questionmark", title: "Device not found", message: "It may have been removed.")
                    .padding(.top, 60)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(device?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename device", isPresented: $editingName) {
            TextField("Name", text: $draftName)
            Button("Save") { state.renameDevice(deviceID, to: draftName) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func header(_ device: Device) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.bgElevated).frame(width: 84, height: 84)
                Circle().stroke(Theme.accentGradient, lineWidth: 2).frame(width: 84, height: 84)
                Image(systemName: device.iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accentGradient)
            }
            Text(device.displayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                statusBadge(device)
                if device.isGateway { StatusPill(text: "Router", color: Theme.cyan) }
                if device.isThisDevice { StatusPill(text: "This device", color: Theme.accent) }
            }
            Button {
                draftName = device.customName ?? ""
                editingName = true
            } label: {
                Label("Rename", systemImage: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.cyan)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 20)
    }

    private func infoCard(_ device: Device) -> some View {
        VStack(spacing: 0) {
            InfoRow(label: "IP address", value: device.ip, mono: true)
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "MAC address", value: device.mac ?? "Unknown", mono: true)
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Hostname", value: device.hostname ?? "—")
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Manufacturer", value: device.vendor ?? "Unknown")
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Status", value: device.isOnline ? "Online" : "Offline")
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "First seen", value: device.firstSeen.formatted(date: .abbreviated, time: .shortened))
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Last seen", value: device.lastSeen.formatted(date: .abbreviated, time: .shortened))
            if !device.services.isEmpty {
                Divider().overlay(Theme.cardStroke)
                InfoRow(label: "Services", value: device.services.map { $0.replacingOccurrences(of: "._tcp", with: "").replacingOccurrences(of: "_", with: "") }.joined(separator: ", "))
            }
        }
        .cardStyle(padding: 14)
    }

    @ViewBuilder private func accessCard(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network access")
                .font(.headline).foregroundStyle(Theme.textPrimary)

            if device.isThisDevice {
                Text("You can't block the device you're using.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            } else if !state.config.isConfigured {
                Text("Connect your router in Settings to manage this device's access.")
                    .font(.caption).foregroundStyle(Theme.warning)
            } else if !state.config.kind.canAttemptRestrictions {
                Text(state.config.kind.supportSummary)
                    .font(.caption).foregroundStyle(Theme.warning)
            } else if device.mac == nil {
                Text("A MAC address is required to manage access, and none was detected for this device. Try another scan.")
                    .font(.caption).foregroundStyle(Theme.warning)
            } else {
                let isRestricted = device.accessStatus == .restricted
                Text(isRestricted
                     ? "This device is currently blocked at the router."
                     : "Blocking uses your \(state.config.kind.displayName) router's own access controls. The change only shows here after the router confirms it.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)

                Button {
                    if isRestricted {
                        Task { await perform(restrict: false) }
                    } else {
                        confirmRestrict = true
                    }
                } label: {
                    HStack {
                        if working { ProgressView().tint(.black) }
                        Image(systemName: isRestricted ? "checkmark.shield.fill" : "hand.raised.fill")
                        Text(isRestricted ? "Restore access" : "Block internet access")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isRestricted ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.danger),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(isRestricted ? .black : .white)
                }
                .disabled(working)
                .confirmationDialog("Block \(device.displayName)?",
                                    isPresented: $confirmRestrict, titleVisibility: .visible) {
                    Button("Block internet access", role: .destructive) {
                        Task { await perform(restrict: true) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This tells your router to stop this device from reaching the internet. You can restore it any time.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func perform(restrict: Bool) async {
        guard let device else { return }
        working = true
        await state.setRestricted(device, restricted: restrict)
        working = false
    }

    private func statusBadge(_ device: Device) -> some View {
        Group {
            switch device.accessStatus {
            case .restricted: StatusPill(text: "Blocked", color: Theme.danger, filled: true)
            default:
                device.isOnline ? StatusPill(text: "Online", color: Theme.success)
                                : StatusPill(text: "Offline", color: Theme.textTertiary)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? .caption.monospaced() : .caption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 10)
    }
}
