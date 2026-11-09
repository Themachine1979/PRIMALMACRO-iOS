import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sex: FormulaSex = .male
    @State private var age = "32"
    @State private var height = "178"
    @State private var weight = "82"
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: FitnessGoal = .lose

    private var isTeen: Bool { (13..<18).contains(Int(age) ?? 0) }
    private var valid: Bool {
        guard let years = Int(age), (13...100).contains(years) else { return false }
        if years < 18 { return true }
        guard let h = Double(height), let w = Double(weight) else { return false }
        return (120...240).contains(h) && (30...400).contains(w)
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
                Text(isTeen
                     ? "Log your food and see daily nutrition totals. We don't set calorie, weight-loss or macro targets for under-18s."
                     : "Tell us about yourself. We'll calculate a starting calorie and macro target for your goal.")
                    .foregroundStyle(PM.secondary)
                PMPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        PMField(title: "Age", value: $age, suffix: "years")
                        if !isTeen {
                            Text("BMR FORMULA").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                            Picker("BMR formula", selection: $sex) {
                                ForEach(FormulaSex.allCases) { choice in Text(choice.rawValue).tag(choice) }
                            }
                            .pickerStyle(.segmented)
                            PMField(title: "Height", value: $height, suffix: "cm")
                            PMField(title: "Current weight", value: $weight, suffix: "kg")
                            Text("This option selects a sex-based calculation coefficient; it isn't a statement of gender identity.")
                                .font(.caption2).foregroundStyle(PM.secondary)
                        } else {
                            Text("No body weight, height or sex information is needed for the under-18 food diary.")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                }
                if !isTeen {
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
                }
                Text(isTeen
                     ? "For ages 13–17: this is a food diary, not a calorie goal or diet plan. Nutrition estimates aren't medical advice."
                     : "Adult calorie targets are estimates, not medical advice. Review your needs with a professional when appropriate.")
                    .font(.caption).foregroundStyle(PM.secondary)
                PMLargeButton(title: isTeen ? "START MY FOOD DIARY" : "CALCULATE MY PLAN",
                              icon: "bolt.fill", enabled: valid) {
                    guard let years = Int(age), (13...100).contains(years) else { return }
                    if years < 18 {
                        store.saveProfile(FitnessProfile(formulaSex: nil, age: years,
                            heightCm: nil, weightKg: nil, activity: .moderate, goal: .maintain,
                            targetWeightKg: nil))
                    } else {
                        guard let cm = Double(height), let kg = Double(weight) else { return }
                        store.saveProfile(FitnessProfile(formulaSex: sex, age: years, heightCm: cm,
                            weightKg: kg, activity: activity, goal: goal, targetWeightKg: nil))
                    }
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PM.background)
    }
}
