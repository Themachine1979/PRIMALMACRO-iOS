import SwiftUI

enum PM {
    static let background = Color(red: 0.047, green: 0.053, blue: 0.058)
    static let surface = Color(red: 0.095, green: 0.101, blue: 0.107)
    static let elevated = Color(red: 0.14, green: 0.15, blue: 0.16)
    static let orange = Color(red: 1, green: 0.37, blue: 0.035)
    static let orangeLight = Color(red: 1, green: 0.58, blue: 0.21)
    static let secondary = Color(red: 0.62, green: 0.65, blue: 0.68)
    static let green = Color(red: 0.46, green: 0.89, blue: 0.40)
}

struct PMPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PM.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.045), lineWidth: 1))
    }
}

struct PMLargeButton: View {
    var title: String
    var icon: String? = nil
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.headline.weight(.heavy)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .foregroundStyle(.white)
            .background(enabled ? PM.orange : PM.elevated,
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
    }
}

struct PMSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.heavy))
            Spacer()
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(PM.secondary) }
        }
    }
}

struct PMBrand: View {
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 30 : 42, height: compact ? 30 : 42)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 0) {
                Text("PRIMAL").foregroundStyle(.white)
                Text("MACRO").foregroundStyle(PM.orange)
            }
            .font(.system(size: compact ? 19 : 27, weight: .black, design: .rounded))
            .italic()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PMNumber: View {
    var number: String
    var unit: String
    var label: String
    var color: Color = PM.orange
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(PM.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(number).font(.title2.weight(.heavy)).monospacedDigit()
                Text(unit).font(.caption.weight(.bold)).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PMField: View {
    var title: String
    @Binding var value: String
    var suffix: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold)).foregroundStyle(PM.secondary)
            HStack {
                TextField(title, text: $value)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                Text(suffix).foregroundStyle(PM.secondary)
            }
            .padding(13)
            .background(PM.elevated, in: RoundedRectangle(cornerRadius: 11))
        }
    }
}

extension Double {
    var compactString: String { formatted(.number.precision(.fractionLength(0...1))) }
}
