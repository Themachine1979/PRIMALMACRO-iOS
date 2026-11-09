import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    var openScanner: () -> Void
    var openDiary: () -> Void

    private var today: [FoodEntry] { store.foods(on: Date()) }
    private var eaten: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        store.total(on: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    PMBrand(compact: true)
                    Spacer()
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.caption.weight(.semibold)).foregroundStyle(PM.secondary)
                }
                .padding(.top, 20)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR DAILY FUEL")
                            .font(.caption2.weight(.heavy)).tracking(2).foregroundStyle(PM.orange)
                        Text("STAY ON TARGET.")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "flame.fill").font(.title).foregroundStyle(PM.orange)
                }
                if store.profile?.isTeen == true {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("YOUR FOOD DIARY")
                                .font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                            Text("\(eaten.calories.formatted()) kcal logged today")
                                .font(.title2.weight(.heavy))
                            HStack(spacing: 12) {
                                PMNumber(number: "\(Int(eaten.protein))", unit: "g", label: "Protein logged")
                                PMNumber(number: "\(Int(eaten.carbs))", unit: "g", label: "Carbs logged")
                                PMNumber(number: "\(Int(eaten.fat))", unit: "g", label: "Fat logged")
                            }
                            Text("Food totals only. No calorie budgets, weight-loss goals or target comparisons for ages 13–17.")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                } else if let target = store.targets {
                    PMPanel {
                        VStack(spacing: 18) {
                            CalorieRing(consumed: eaten.calories, target: target.calories)
                                .frame(height: 215)
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 12) {
                                MacroCard(title: "Protein", current: eaten.protein, target: target.proteinG, color: PM.orangeLight, icon: "dumbbell.fill")
                                MacroCard(title: "Carbs", current: eaten.carbs, target: target.carbsG, color: PM.orange, icon: "leaf.fill")
                                MacroCard(title: "Fat", current: eaten.fat, target: target.fatG, color: .yellow, icon: "drop.fill")
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button(action: openScanner) {
                        Label("SCAN FOOD", systemImage: "camera.fill")
                            .font(.subheadline.weight(.heavy))
                            .frame(maxWidth: .infinity).frame(height: 51)
                            .foregroundStyle(.white)
                            .background(PM.orange, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button(action: openDiary) {
                        Label("FOOD DIARY", systemImage: "list.bullet")
                            .font(.subheadline.weight(.heavy))
                            .frame(maxWidth: .infinity).frame(height: 51)
                            .foregroundStyle(.white)
                            .background(PM.elevated, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                PMSectionTitle(title: "Meals Today", subtitle: "\(today.count) recorded")
                if today.isEmpty {
                    PMPanel {
                        HStack(spacing: 12) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.largeTitle).foregroundStyle(PM.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No meals logged yet").font(.headline)
                                Text("Scan a meal or add food manually in your diary.")
                                    .font(.caption).foregroundStyle(PM.secondary)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 9) {
                        ForEach(today.prefix(6)) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: entry.meal.icon)
                                    .foregroundStyle(PM.orange)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name).font(.subheadline.weight(.bold)).lineLimit(1)
                                    Text("\(entry.meal.rawValue) • \(Int(entry.proteinG))g protein")
                                        .font(.caption).foregroundStyle(PM.secondary)
                                }
                                Spacer()
                                Text("\(entry.calories) kcal")
                                    .font(.subheadline.weight(.bold)).monospacedDigit()
                            }
                            .padding(15)
                            .background(PM.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                if let profile = store.profile, profile.isAdult {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("THE MISSION", systemImage: "scope")
                                .font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                            Text(profile.goal.rawValue).font(.title3.weight(.heavy))
                            Text("Nutrition targets are estimates. Monitor energy, recovery and weekly trends, then adjust gradually.")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(PM.background)
    }
}

private struct CalorieRing: View {
    let consumed: Int
    let target: Int
    private var progress: CGFloat { CGFloat(min(1, Double(consumed) / Double(max(1, target)))) }

    var body: some View {
        ZStack {
            Circle().stroke(PM.elevated, lineWidth: 19)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [PM.orangeLight, PM.orange], center: .center),
                        style: StrokeStyle(lineWidth: 19, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 5) {
                Image(systemName: "flame.fill").foregroundStyle(PM.orange).font(.title2)
                Text("\(consumed.formatted()) / \(target.formatted())")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .monospacedDigit()
                Text("KCAL CONSUMED")
                    .font(.caption2.weight(.bold)).foregroundStyle(PM.secondary)
                Text(consumed <= target ? "\(target - consumed) kcal remaining" : "\(consumed - target) kcal above target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(consumed <= target ? PM.green : PM.orangeLight)
            }
        }
        .frame(width: 205, height: 205)
        .accessibilityElement(children: .combine)
    }
}

private struct MacroCard: View {
    let title: String
    let current: Double
    let target: Int
    let color: Color
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(PM.secondary)
            Text("\(Int(current))/\(target)g")
                .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PM.elevated)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(1, current / Double(max(1,target))))
                }
            }
            .frame(height: 5)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PM.background, in: RoundedRectangle(cornerRadius: 12))
    }
}
