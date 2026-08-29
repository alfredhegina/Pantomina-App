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

    var body: some View {
        Circle()
            .fill(person == .fern ? Color.pantomina.sage : Color.pantomina.terra)
            .frame(width: 10, height: 10)
            .accessibilityLabel(person.rawValue)
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
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    withAnimation(PantominaMotion.feedback) {
                        selection = index
                    }
                } label: {
                    Text(options[index])
                        .font(PantominaFont.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(selection == index ? Color.pantomina.sage : Color.clear)
                        .foregroundStyle(selection == index ? Color.white : Color.pantomina.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.pantomina.hairline)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
