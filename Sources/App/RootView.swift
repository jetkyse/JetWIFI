import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .dashboard

    enum Tab: Hashable { case dashboard, devices, restricted, history, settings }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            TabView(selection: $tab) {
                DashboardView(tab: $tab)
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                    .tag(Tab.dashboard)

                DevicesView()
                    .tabItem { Label("Devices", systemImage: "externaldrive.connected.to.line.below.fill") }
                    .tag(Tab.devices)

                RestrictedView()
                    .tabItem { Label("Restricted", systemImage: "hand.raised.fill") }
                    .tag(Tab.restricted)

                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    .tag(Tab.history)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }

            BannerOverlay()
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

/// Floating banner for action results.
struct BannerOverlay: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack {
            if let banner = state.banner {
                HStack(spacing: 10) {
                    Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(banner.isError ? Theme.danger : Theme.success)
                    Text(banner.text)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.bgElevated)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardStroke))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { state.banner = nil }
                    }
                }
                .onTapGesture { withAnimation { state.banner = nil } }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.banner)
    }
}
