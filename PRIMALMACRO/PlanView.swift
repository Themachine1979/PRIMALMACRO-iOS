import SwiftUI
import UIKit

struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var member: AppleMemberSession
    @AppStorage("primalmacro.ai.photoConsent") private var photoConsent = false
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var deletingAccount = false
    @State private var deleteAccountError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("YOUR PLAN")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .padding(.top, 20)
                if let profile = store.profile, let target = store.targets {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("THE MISSION").font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                            Text(profile.goal.rawValue.uppercased()).font(.title2.weight(.heavy))
                            Text(profile.goal.subtitle).font(.caption).foregroundStyle(PM.secondary)
                            Divider().overlay(PM.elevated)
                            HStack {
                                PMNumber(number: "\(target.calories)", unit: "kcal", label: "Daily target")
                                PMNumber(number: "\(target.maintenanceCalories)", unit: "kcal", label: "Maintenance est.")
                            }
                            HStack {
                                PMNumber(number: "\(target.proteinG)", unit: "g", label: "Protein")
                                PMNumber(number: "\(target.carbsG)", unit: "g", label: "Carbs")
                                PMNumber(number: "\(target.fatG)", unit: "g", label: "Fat")
                            }
                        }
                    }
                    PMPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("HOW IT WORKS", systemImage: "info.circle")
                                .font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                            Text("Mifflin–St Jeor estimates resting energy (\(target.bmr) kcal), then an activity multiplier estimates maintenance. The plan applies a moderate adjustment based on your goal.")
                                .font(.subheadline).foregroundStyle(PM.secondary)
                            Text("Protein is estimated from body weight, fat from a calorie share and carbs from the remainder. Targets may need adjustment based on results and professional advice.")
                                .font(.subheadline).foregroundStyle(PM.secondary)
                        }
                    }
                }
                VStack(spacing: 10) {
                    settingsButton("Edit profile & goal", icon: "person.crop.circle") { showEdit = true }
                    settingsButton("Manage subscription", icon: "creditcard.fill") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    settingsButton("Sign out", icon: "rectangle.portrait.and.arrow.right") { member.signOut() }
                    if member.isEmailAccount {
                        settingsButton("Delete my email account", icon: "person.crop.circle.badge.xmark") {
                            showDeleteAccountAlert = true
                        }
                    }
                    if let deleteAccountError {
                        Text(deleteAccountError).font(.footnote).foregroundStyle(.red)
                    }
                    if photoConsent {
                        settingsButton("Reset AI photo permission", icon: "hand.raised") { photoConsent = false }
                    }
                    settingsButton("Delete all local data", icon: "trash") { showDeleteAlert = true }
                }
                PMPanel {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("PRIVATE BY DESIGN").font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                        Text("Food diary, body measurements and profile stay on this iPhone. Images are sent to the PRIMALMACRO AI service only when you choose to analyse them. No cross-device sync yet.")
                            .font(.caption).foregroundStyle(PM.secondary)
                        Text("For adults 18+. Not for treating medical conditions or prescribing diets.")
                            .font(.caption).foregroundStyle(PM.secondary)
                    }
                }
                Text("PRIMALMACRO v0.2")
                    .font(.caption2.weight(.medium)).foregroundStyle(PM.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 35)
        }
        .background(PM.background)
        .sheet(isPresented: $showEdit) { EditProfileView() }
        .confirmationDialog("Delete your PRIMALMACRO email account and this phone's diary? This can't be undone.",
                            isPresented: $showDeleteAccountAlert, titleVisibility: .visible) {
            Button("Delete account and local data", role: .destructive) {
                guard !deletingAccount else { return }
                deletingAccount = true
                Task {
                    do {
                        try await member.deleteEmailAccount()
                        store.clearAllData()
                        photoConsent = false
                        deleteAccountError = nil
                    } catch {
                        deleteAccountError = "Couldn't delete account: \(error.localizedDescription). Try signing in again."
                    }
                    deletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your diary, profile and weight records from this phone?",
                            isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete all local data", role: .destructive) {
                store.clearAllData()
                photoConsent = false
                member.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func settingsButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(PM.orange).frame(width: 28)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(PM.secondary)
            }
            .padding(17)
            .background(PM.surface, in: RoundedRectangle(cornerRadius: 13))
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sex: FormulaSex = .male
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: FitnessGoal = .lose

    private var valid: Bool {
        guard let years = Int(age), let cm = Double(height), let kg = Double(weight) else { return false }
        return (18...100).contains(years) && (120...240).contains(cm) && (30...400).contains(kg)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    Text("BMR FORMULA").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                    Picker("Formula", selection: $sex) {
                        ForEach(FormulaSex.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        PMField(title: "Age", value: $age, suffix: "yr")
                        PMField(title: "Height", value: $height, suffix: "cm")
                    }
                    PMField(title: "Weight", value: $weight, suffix: "kg")
                    Text("ACTIVITY").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                    Picker("Activity", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Text("GOAL").font(.caption.weight(.heavy)).foregroundStyle(PM.secondary)
                    Picker("Goal", selection: $goal) {
                        ForEach(FitnessGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    PMLargeButton(title: "UPDATE TARGETS", enabled: valid) {
                        guard let years = Int(age), let cm = Double(height), let kg = Double(weight) else { return }
                        store.saveProfile(FitnessProfile(formulaSex: sex, age: years, heightCm: cm, weightKg: kg,
                                                        activity: activity, goal: goal, targetWeightKg: nil))
                        dismiss()
                    }
                }
                .padding(18)
            }
            .background(PM.background)
            .navigationTitle("Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            guard let p = store.profile else { return }
            sex = p.formulaSex; age = "\(p.age)"; height = p.heightCm.compactString
            weight = p.weightKg.compactString; activity = p.activity; goal = p.goal
        }
    }
}
