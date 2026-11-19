import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showRouterSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    routerSection
                    aboutSection
                    disclaimerSection
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $showRouterSetup) {
                RouterSetupView().environmentObject(state)
            }
        }
    }

    private var routerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROUTER").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)

            Button { showRouterSetup = true } label: {
                HStack {
                    Image(systemName: "wifi.router.fill").foregroundStyle(Theme.accentGradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.config.isConfigured ? state.config.kind.displayName : "Add your router")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(state.config.isConfigured ? (state.config.host.isEmpty ? "Tap to edit" : state.config.host)
                                                       : "Required to manage device access")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if state.config.isConfigured {
                Text(state.config.kind.supportSummary)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
            InfoRow(label: "Version", value: appVersion)
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Discovery", value: "Bonjour + ARP + reverse DNS")
            Divider().overlay(Theme.cardStroke)
            InfoRow(label: "Credentials", value: "Stored in iOS Keychain")
        }
        .cardStyle()
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Use on your own network", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.cyan)
            Text("JetWIFI manages access through your router's own admin controls, using credentials you provide. Only use it on a network you own or administer. It does not spoof, intercept, or alter other devices' traffic.")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle()
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
