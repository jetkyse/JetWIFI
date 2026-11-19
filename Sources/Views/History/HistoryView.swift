import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if state.history.isEmpty {
                        EmptyHint(icon: "clock", title: "No activity yet",
                                  message: "Scans, new devices, and access changes are logged here.")
                            .padding(.top, 50)
                    } else {
                        ForEach(state.history) { event in
                            HStack(spacing: 12) {
                                Image(systemName: event.iconName)
                                    .font(.callout)
                                    .foregroundStyle(color(for: event.kind))
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    if let detail = event.detail {
                                        Text(detail)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 6)
                                Text(event.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .cardStyle(padding: 12)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !state.history.isEmpty {
                        Button("Clear") { state.clearHistory() }
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
        }
    }

    private func color(for kind: HistoryEvent.Kind) -> Color {
        switch kind {
        case .restrictApplied, .restrictFailed, .routerError: return Theme.danger
        case .restrictRemoved, .routerConnected: return Theme.success
        case .deviceJoined, .deviceDiscovered: return Theme.cyan
        case .deviceLeft: return Theme.textTertiary
        }
    }
}
