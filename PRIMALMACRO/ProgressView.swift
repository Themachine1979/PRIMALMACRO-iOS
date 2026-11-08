import SwiftUI
import Charts

struct WeightProgressView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showWeight = false
    @State private var newWeight = ""

    private var latest: Double? { store.weights.last?.kg }
    private var change: Double? {
        guard let first = store.weights.first, let last = store.weights.last else { return nil }
        return last.kg - first.kg
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                Text("PROGRESS")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .padding(.top, 20)
                HStack(spacing: 12) {
                    PMPanel {
                        PMNumber(number: latest?.compactString ?? "—", unit: "kg", label: "Current weight")
                    }
                    PMPanel {
                        PMNumber(number: change.map { String(format: "%+.1f", $0) } ?? "—",
                                 unit: "kg", label: "Total change",
                                 color: (change ?? 0) <= 0 ? PM.green : PM.orange)
                    }
                }
                PMSectionTitle(title: "Weight Trend", subtitle: "Latest measurements")
                PMPanel {
                    if store.weights.count < 2 {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(PM.orange)
                            Text("Log more weigh-ins to see your trend.")
                                .font(.subheadline).foregroundStyle(PM.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    } else {
                        Chart(store.weights) { entry in
                            LineMark(x: .value("Date", entry.date), y: .value("Weight", entry.kg))
                                .foregroundStyle(PM.orange)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", entry.date), y: .value("Weight", entry.kg))
                                .foregroundStyle(PM.orangeLight)
                        }
                        .chartYScale(domain: chartRange)
                        .frame(height: 230)
                    }
                }
                PMSectionTitle(title: "Weigh-ins", subtitle: "\(store.weights.count) total")
                ForEach(Array(store.weights.suffix(12).reversed())) { entry in
                    HStack {
                        Image(systemName: "scalemass.fill").foregroundStyle(PM.orange)
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(PM.secondary)
                        Spacer()
                        Text("\(entry.kg.compactString) kg").font(.headline.weight(.heavy))
                    }
                    .padding(15)
                    .background(PM.surface, in: RoundedRectangle(cornerRadius: 13))
                }
                PMLargeButton(title: "LOG WEIGHT", icon: "plus") {
                    newWeight = latest?.compactString ?? ""
                    showWeight = true
                }
                PMPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROGRESS OVER PERFECTION").font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                        Text("Use consistent conditions for weigh-ins. Daily weight fluctuates with hydration, meals and training.")
                            .font(.caption).foregroundStyle(PM.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 35)
        }
        .background(PM.background)
        .sheet(isPresented: $showWeight) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 22) {
                    PMField(title: "Current weight", value: $newWeight, suffix: "kg")
                    PMLargeButton(title: "SAVE WEIGH-IN", enabled: Double(newWeight).map { (30...400).contains($0) } == true) {
                        if let kg = Double(newWeight) {
                            store.addWeight(kg)
                            showWeight = false
                        }
                    }
                    Spacer()
                }
                .padding(20)
                .background(PM.background)
                .navigationTitle("New weigh-in")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { showWeight = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private var chartRange: ClosedRange<Double> {
        let values = store.weights.map(\.kg)
        let lo = values.min() ?? 50
        let hi = values.max() ?? 100
        return (max(0, lo - 2))...(hi + 2)
    }
}
