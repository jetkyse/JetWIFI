import SwiftUI

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.bgElevated)
                    .frame(width: 46, height: 46)
                Image(systemName: device.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(device.isOnline ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.textTertiary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(device.ip)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                    if let vendor = device.vendor {
                        Text("· \(vendor)")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            statusPill
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var statusPill: some View {
        switch device.accessStatus {
        case .restricted:
            StatusPill(text: "Blocked", color: Theme.danger, filled: true)
        case .allowed where device.isOnline:
            StatusPill(text: "Online", color: Theme.success)
        default:
            if device.isOnline {
                StatusPill(text: "Online", color: Theme.success)
            } else {
                StatusPill(text: "Offline", color: Theme.textTertiary)
            }
        }
    }
}
