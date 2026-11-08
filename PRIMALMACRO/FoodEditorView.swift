import SwiftUI

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var initial: FoodEstimate?
    var date: Date = Date()
    var onSave: (FoodEntry) -> Void

    @State private var name = ""
    @State private var serving = "1 serving"
    @State private var meal: Meal = .lunch
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(kcal).map { (0...10_000).contains($0) } == true &&
        [protein, carbs, fat, fiber].allSatisfy { Double($0).map { (0...1_000).contains($0) } == true }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("CONFIRM YOUR NUTRITION")
                        .font(.caption.weight(.heavy)).tracking(1.4).foregroundStyle(PM.orange)
                    if let initial {
                        Text("AI confidence: \(initial.confidence.capitalized). Check the portion and label before saving.")
                            .font(.caption).foregroundStyle(PM.secondary)
                        if !initial.notes.isEmpty {
                            Text(initial.notes).font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                    editorTextField("Food name", text: $name)
                    editorTextField("Serving / portion", text: $serving)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal").font(.caption.weight(.bold)).foregroundStyle(PM.secondary)
                        Picker("Meal", selection: $meal) {
                            ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack(spacing: 10) {
                        PMField(title: "Calories", value: $kcal, suffix: "kcal")
                        PMField(title: "Protein", value: $protein, suffix: "g")
                    }
                    HStack(spacing: 10) {
                        PMField(title: "Carbs", value: $carbs, suffix: "g")
                        PMField(title: "Fat", value: $fat, suffix: "g")
                    }
                    PMField(title: "Fibre", value: $fiber, suffix: "g")
                    Text("Photos and menus only give approximate nutrition. Packaging values are limited by visible text and portion information.")
                        .font(.caption).foregroundStyle(PM.secondary)
                    PMLargeButton(title: "SAVE TO MY DIARY", icon: "checkmark", enabled: valid) {
                        let entry = FoodEntry(date: date,
                                              meal: meal,
                                              name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                              serving: serving,
                                              calories: Int(kcal) ?? 0,
                                              proteinG: Double(protein) ?? 0,
                                              carbsG: Double(carbs) ?? 0,
                                              fatG: Double(fat) ?? 0,
                                              fiberG: Double(fiber) ?? 0,
                                              source: initial == nil ? "manual" : "ai-reviewed")
                        onSave(entry)
                    }
                }
                .padding(18)
            }
            .background(PM.background)
            .navigationTitle(initial == nil ? "Add food" : "Review scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let initial {
                name = initial.name
                serving = initial.serving
                kcal = String(initial.calories)
                protein = initial.proteinG.compactString
                carbs = initial.carbsG.compactString
                fat = initial.fatG.compactString
                fiber = initial.fiberG.compactString
            } else {
                kcal = "0"; protein = "0"; carbs = "0"; fat = "0"; fiber = "0"
            }
        }
    }

    private func editorTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(PM.secondary)
            TextField(title, text: text)
                .padding(13)
                .background(PM.elevated, in: RoundedRectangle(cornerRadius: 11))
        }
    }
}
