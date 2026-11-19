import SwiftUI

struct RouterSetupView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var kind: RouterKind = .generic
    @State private var host: String = ""
    @State private var username: String = "admin"
    @State private var password: String = ""
    @State private var useHTTPS = false
    @State private var accountEmail = ""
    @State private var testing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    brandPicker
                    supportNote
                    if kind.canAttemptRestrictions { credentialsCard }
                    saveButton
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Router setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var brandPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROUTER BRAND").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
            ForEach(RouterKind.allCases) { k in
                Button { withAnimation { kind = k } } label: {
                    HStack {
                        Text(k.displayName).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if kind == k { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        else { Image(systemName: "circle").foregroundStyle(Theme.textTertiary) }
                    }
                    .padding(.vertical, 10)
                }
                if k != RouterKind.allCases.last { Divider().overlay(Theme.cardStroke) }
            }
        }
        .cardStyle()
    }

    private var supportNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.canAttemptRestrictions ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(kind.canAttemptRestrictions ? Theme.cyan : Theme.warning)
            Text(kind.supportSummary)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADMIN LOGIN").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)

            if kind == .eero {
                Field(title: "Account email", text: $accountEmail, keyboard: .emailAddress)
            } else {
                Field(title: "Router address", text: $host, placeholder: state.gateway?.ip ?? "192.168.1.1", keyboard: .numbersAndPunctuation)
                Field(title: "Username", text: $username)
                SecureFieldRow(title: "Password", text: $password)
                Toggle("Use HTTPS", isOn: $useHTTPS)
                    .font(.subheadline).tint(Theme.accent).foregroundStyle(Theme.textPrimary)
            }
        }
        .cardStyle()
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if testing { ProgressView().tint(.black) }
                Text(testing ? "Testing connection…" : (kind.canAttemptRestrictions ? "Connect & save" : "Save"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.black)
        }
        .disabled(testing)
    }

    private func loadExisting() {
        let c = state.config
        kind = c.kind
        host = c.host
        username = c.username.isEmpty ? "admin" : c.username
        useHTTPS = c.useHTTPS
        accountEmail = c.accountEmail
        if c.isConfigured { password = KeychainService.loadPassword() ?? "" }
    }

    private func save() async {
        testing = true
        var cfg = RouterConfig()
        cfg.kind = kind
        cfg.host = host.isEmpty ? (state.gateway?.ip ?? "") : host
        cfg.username = username
        cfg.useHTTPS = useHTTPS
        cfg.accountEmail = accountEmail
        let ok = await state.saveRouter(cfg, password: password)
        testing = false
        if ok || !kind.canAttemptRestrictions { dismiss() }
    }
}

struct Field: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(Theme.textTertiary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SecureFieldRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(Theme.textTertiary)
            SecureField("", text: $text)
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
