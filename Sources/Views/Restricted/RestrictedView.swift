import SwiftUI

struct RestrictedView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if state.restrictedDevices.isEmpty {
                        EmptyHint(icon: "hand.raised.slash", title: "Nothing blocked",
                                  message: "Devices you block at the router appear here, so you can restore them in one tap.")
                            .padding(.top, 50)
                    } else {
                        ForEach(state.restrictedDevices) { device in
                            HStack {
                                NavigationLink(value: device.id) {
                                    DeviceRow(device: device)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    Task { await state.setRestricted(device, restricted: false) }
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Theme.success)
                                }
                            }
                            .cardStyle(padding: 12)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Restricted")
            .navigationDestination(for: String.self) { id in
                DeviceDetailView(deviceID: id)
            }
        }
    }
}
