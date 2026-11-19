import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var showOfflineToo = true

    private var filtered: [Device] {
        state.devices.filter { d in
            (showOfflineToo || d.isOnline) &&
            (query.isEmpty ||
             d.displayName.localizedCaseInsensitiveContains(query) ||
             d.ip.contains(query) ||
             (d.vendor ?? "").localizedCaseInsensitiveContains(query) ||
             (d.mac ?? "").localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Toggle("Show offline devices", isOn: $showOfflineToo)
                        .font(.caption)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    if filtered.isEmpty {
                        EmptyHint(icon: "magnifyingglass", title: "Nothing here",
                                  message: state.devices.isEmpty ? "Run a scan from the Dashboard." : "No devices match your search.")
                            .padding(.top, 40)
                    } else {
                        ForEach(filtered) { device in
                            NavigationLink(value: device.id) {
                                DeviceRow(device: device).cardStyle(padding: 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Devices")
            .searchable(text: $query, prompt: "Name, IP, MAC, vendor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await state.scan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(state.isScanning)
                }
            }
            .navigationDestination(for: String.self) { id in
                DeviceDetailView(deviceID: id)
            }
        }
    }
}
