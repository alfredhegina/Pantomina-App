import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pantomina.card)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous)
                    .stroke(Color.pantomina.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(PantominaFont.eyebrow)
            .tracking(1.2)
            .foregroundStyle(Color.pantomina.muted)
    }
}

struct PetTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(PantominaFont.petTitle)
            .foregroundStyle(Color.pantomina.ink)
    }
}

struct Amount: View {
    let centavos: Int
    var fractionDigits: Int = 2

    var body: some View {
        Text(formatPeso(centavos, fractionDigits: fractionDigits))
            .font(PantominaFont.amount)
            .foregroundStyle(Color.pantomina.ink)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct PersonDot: View {
    let person: PersonId
    var displayName: String?

    var body: some View {
        Circle()
            .fill(person == .fern ? Color.pantomina.sage : Color.pantomina.terra)
            .frame(width: 10, height: 10)
            .accessibilityLabel(displayName ?? (person == .fern ? "Payer" : "Contributor"))
    }
}

enum ChipTone {
    case neutral, blush, sage, terra
}

struct Chip: View {
    let label: String
    var tone: ChipTone = .neutral

    var body: some View {
        Text(label)
            .font(PantominaFont.caption)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 32)
            .padding(.vertical, Spacing.xs)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .accessibilityAddTraits(.isStaticText)
    }

    private var background: Color {
        switch tone {
        case .neutral: return Color.pantomina.hairline
        case .blush: return Color.pantomina.blush
        case .sage: return Color.pantomina.sage.opacity(0.15)
        case .terra: return Color.pantomina.terra.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return Color.pantomina.ink
        case .blush: return Color.pantomina.rose
        case .sage: return Color.pantomina.sageDeep
        case .terra: return Color.pantomina.terraDeep
        }
    }
}

struct Seg: View {
    let options: [String]
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if options.count <= 4 {
                equalWidthBar
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    barContent(equalWidth: false)
                }
            }
        }
    }

    private var equalWidthBar: some View {
        barContent(equalWidth: true)
    }

    private func barContent(equalWidth: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    PantominaMotion.run(reduceMotion) {
                        selection = index
                    }
                } label: {
                    Text(options[index])
                        .font(PantominaFont.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, equalWidth ? Spacing.sm : Spacing.md)
                        .frame(maxWidth: equalWidth ? .infinity : nil)
                        .frame(minHeight: 44)
                        .background(selection == index ? Color.pantomina.sage : Color.clear)
                        .foregroundStyle(selection == index ? Color.white : Color.pantomina.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(options[index])
            }
        }
        .background(Color.pantomina.hairline)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Quiet ledger

struct QuietLedgerRow: View {
    var title: String
    var amountC: Int
    var amountColor: Color
    var caption: String
    var pendingLabel: String? = nil
    var dimmed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: pendingLabel == nil ? 3 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(PantominaFont.body.weight(.medium))
                    .foregroundStyle(Color.pantomina.ink)
                Spacer(minLength: 8)
                Text(formatPeso(amountC))
                    .font(PantominaFont.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(amountColor)
            }
            HStack(spacing: 8) {
                Text(caption)
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                if let pendingLabel {
                    Text(pendingLabel)
                        .font(PantominaFont.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.pantomina.terra.opacity(0.18))
                        .foregroundStyle(Color.pantomina.ink)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 11)
        .opacity(dimmed ? 0.72 : 1)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.pantomina.innerRule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct QuietEmptyBlock: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var filled: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.pantomina.hairline)
                .accessibilityHidden(true)
            Text(title)
                .font(PantominaFont.body.weight(.medium))
                .foregroundStyle(Color.pantomina.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PantominaFont.body.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 18)
                        .background(filled ? Color.pantomina.quietAccent : Color.clear)
                        .foregroundStyle(filled ? Color.white : Color.pantomina.quietAccent)
                        .overlay {
                            if !filled {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.pantomina.quietAccent, lineWidth: 1)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(SageButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

struct QuietPrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(enabled ? Color.pantomina.quietAccent : Color(hex: "#B9C7BF"))
                .foregroundStyle(enabled ? Color.white : Color(hex: "#F4F7F5"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SageButtonStyle())
        .disabled(!enabled)
    }
}

struct QuietOutlineButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .foregroundStyle(Color.pantomina.terraDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#C9A98F"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct QuietStatusChip: View {
    var label: String
    var tone: ChipTone = .neutral

    var body: some View {
        Text(label)
            .font(.custom("DM Sans", size: 11, relativeTo: .caption2).weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .accessibilityAddTraits(.isStaticText)
    }

    private var background: Color {
        switch tone {
        case .neutral: return Color.pantomina.hairline
        case .blush: return Color.pantomina.blush
        case .sage: return Color(hex: "#E4EEE7")
        case .terra: return Color(hex: "#F0E3DA")
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return Color.pantomina.ink
        case .blush: return Color.pantomina.rose
        case .sage: return Color.pantomina.quietAccent
        case .terra: return Color(hex: "#8A4C2A")
        }
    }
}

/// 40pt-tall pill track used on Add (Paid by / Split / jar kind).
struct QuietSegmented<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value
    var enabled: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let item = options[index]
                let on = selection == item.value
                Button {
                    guard enabled else { return }
                    selection = item.value
                } label: {
                    Text(item.title)
                        .font(PantominaFont.caption.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? Color.pantomina.ink : Color.pantomina.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.pantomina.card)
                                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(Color.pantomina.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(enabled ? 1 : 0.5)
    }
}

struct QuietScopeTabs<Tab: Hashable>: View {
    let tabs: [(title: String, value: Tab)]
    @Binding var selection: Tab
    var spacing: CGFloat = 24

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(tabs.indices, id: \.self) { index in
                let item = tabs[index]
                let selected = selection == item.value
                Button {
                    selection = item.value
                } label: {
                    Text(item.title)
                        .font(PantominaFont.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.pantomina.ink : Color.pantomina.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selected ? Color.pantomina.ink : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.pantomina.rule)
                .frame(height: 1)
        }
    }
}

struct QuietFilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.caption.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? Color.pantomina.quietAccent : Color.clear)
                .foregroundStyle(selected ? Color.white : Color.pantomina.ink)
                .overlay {
                    Capsule()
                        .stroke(selected ? Color.clear : Color.pantomina.rule, lineWidth: 1)
                }
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
