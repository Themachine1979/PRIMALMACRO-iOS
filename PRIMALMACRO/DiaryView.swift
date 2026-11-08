import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var day = Date()
    @State private var showManual = false

    private var totals: (calories: Int, protein: Double, carbs: Double, fat: Double) { store.total(on: day) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("FOOD DIARY")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .padding(.top, 20)
                PMPanel {
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(PM.orange)
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.subheadline.weight(.bold))
                    }
                }
                PMPanel {
                    HStack {
                        PMNumber(number: "\(totals.calories)", unit: "kcal", label: "Calories")
                        PMNumber(number: "\(Int(totals.protein))", unit: "g", label: "Protein")
                        PMNumber(number: "\(Int(totals.carbs))", unit: "g", label: "Carbs")
                    }
                }
                ForEach(Meal.allCases) { meal in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(meal.rawValue, systemImage: meal.icon)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(store.foods(on: day).filter { $0.meal == meal }.reduce(0) { $0 + $1.calories }) kcal")
                                .font(.caption.weight(.bold)).foregroundStyle(PM.secondary)
                        }
                        let items = store.foods(on: day).filter { $0.meal == meal }
                        if items.isEmpty {
                            Text("No \(meal.rawValue.lowercased()) logged")
                                .font(.caption).foregroundStyle(PM.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(PM.surface, in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            ForEach(items) { item in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.name).font(.subheadline.weight(.bold))
                                        Text("\(item.serving) · P \(Int(item.proteinG))g · C \(Int(item.carbsG))g · F \(Int(item.fatG))g")
                                            .font(.caption2).foregroundStyle(PM.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 5)
                                    Text("\(item.calories)").font(.subheadline.weight(.heavy)).monospacedDigit()
                                    Button(role: .destructive) { store.deleteFood(id: item.id) } label: {
                                        Image(systemName: "trash").foregroundStyle(PM.secondary)
                                    }
                                    .accessibilityLabel("Delete \(item.name)")
                                }
                                .padding(13)
                                .background(PM.surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                PMLargeButton(title: "ADD FOOD MANUALLY", icon: "plus") { showManual = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 35)
        }
        .background(PM.background)
        .sheet(isPresented: $showManual) {
            FoodEditorView(initial: nil, date: day, onSave: { entry in
                store.addFood(entry)
                showManual = false
            })
        }
    }
}
