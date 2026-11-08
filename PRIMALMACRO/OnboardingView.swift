import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sex: FormulaSex = .male
    @State private var age = "32"
    @State private var height = "178"
    @State private var weight = "82"
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: FitnessGoal = .lose

    private var valid: Bool {
        guard let ageValue = Int(age), let h = Double(height), let w = Double(weight) else { return false }
        return (18...100).contains(ageValue) && (120...240).contains(h) && (30...400).contains(w)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Spacer(); PMBrand(); Spacer() }
                    .padding(.top, 24)
                Text("FORGE YOUR\nFUEL PLAN.")
                    .font(.system(size: 39, weight: .black, design: .rounded))
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tell us about yourself. We'll calculate a starting calorie and macro target for your goal.")
                    .foregroundStyle(PM.secondary)
                PMPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("BMR FORMULA").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                        Picker("BMR formula", selection: $sex) {
                            ForEach(FormulaSex.allCases) { choice in Text(choice.rawValue).tag(choice) }
                        }
                        .pickerStyle(.segmented)
                        HStack(spacing: 10) {
                            PMField(title: "Age", value: $age, suffix: "years")
                            PMField(title: "Height", value: $height, suffix: "cm")
                        }
                        PMField(title: "Current weight", value: $weight, suffix: "kg")
                        Text("This option selects a sex-based calculation coefficient; it isn't a statement of gender identity.")
                            .font(.caption2).foregroundStyle(PM.secondary)
                    }
                }
                PMPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("YOUR ACTIVITY").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                        Picker("Activity level", selection: $activity) {
                            ForEach(ActivityLevel.allCases) { choice in Text(choice.rawValue).tag(choice) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                PMPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("YOUR MISSION").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                        ForEach(FitnessGoal.allCases) { choice in
                            Button {
                                goal = choice
                            } label: {
                                HStack {
                                    Image(systemName: goal == choice ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(goal == choice ? PM.orange : PM.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(choice.rawValue).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                        Text(choice.subtitle).font(.caption2).foregroundStyle(PM.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(goal == choice ? PM.orange.opacity(0.1) : .clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                Text("For adults 18+. Estimates are a starting point, not medical advice. Review your needs with a professional when appropriate.")
                    .font(.caption).foregroundStyle(PM.secondary)
                PMLargeButton(title: "CALCULATE MY PLAN", icon: "bolt.fill", enabled: valid) {
                    guard let years = Int(age), let cm = Double(height), let kg = Double(weight) else { return }
                    store.saveProfile(FitnessProfile(formulaSex: sex, age: years, heightCm: cm,
                                                    weightKg: kg, activity: activity, goal: goal,
                                                    targetWeightKg: nil))
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PM.background)
    }
}
