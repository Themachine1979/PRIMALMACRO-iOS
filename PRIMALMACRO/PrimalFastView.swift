import SwiftUI

// PrimalFast is an adult-only timer. Coloured metabolic stages are educational
// prompts, not measurements or predictions of individual biological changes.
struct PrimalFastView: View {
    @EnvironmentObject private var store: AppStore
    @State private var chosenHours = 16
    @State private var showEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    Text("PRIMAL").foregroundStyle(.white)
                    Text("FAST").foregroundStyle(PM.orange)
                }
                .font(.system(size: 30, weight: .black, design: .rounded))
                .italic()
                .padding(.top, 20)

                Text("YOUR FASTING JOURNEY")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(PM.secondary)

                if store.profile?.isAdult != true {
                    PMPanel {
                        Label("Fasting is for adults aged 18 and over.", systemImage: "lock.shield")
                            .foregroundStyle(PM.orange)
                        Text("Your food diary and scanning features remain available.")
                            .font(.subheadline)
                            .foregroundStyle(PM.secondary)
                    }
                } else {
                    if let fast = store.activeFast {
                        activeFastCard(fast)
                    } else {
                        startFastCard
                    }

                    PMPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: Binding(
                                get: { store.fastingRemindersEnabled },
                                set: { store.setFastingReminders($0) }
                            )) {
                                Label("iPhone fasting reminders", systemImage: "bell")
                                    .font(.subheadline.weight(.bold))
                            }
                            .tint(PM.orange)
                            Text("Optional notifications when two hours remain and when your selected fasting goal ends. iPhone notification permission is required.")
                                .font(.caption)
                                .foregroundStyle(PM.secondary)
                            if let message = store.fastingNotificationMessage {
                                Text(message).font(.caption).foregroundStyle(PM.orangeLight)
                            }
                        }
                    }

                    fastingHistory
                }
                Text("Fasting is not suitable for everyone. If you feel unwell, end the fast. Seek medical guidance first if you have a relevant health condition, take medication affected by meals, are pregnant or breastfeeding, or have a history of disordered eating.")
                    .font(.caption2)
                    .foregroundStyle(PM.secondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 18)
        }
        .background(PM.background)
        .confirmationDialog("End your current fast?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End fast") { store.endFast() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your fasting time will be saved in history. You can start a new fast whenever you choose.")
        }
    }

    private var startFastCard: some View {
        PMPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("CHOOSE YOUR FAST")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(PM.orange)
                Text("\(chosenHours):\(24 - chosenHours)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("\(chosenHours) hours fasting · \(24 - chosenHours) hours eating")
                    .font(.subheadline)
                    .foregroundStyle(PM.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach([12, 14, 16, 18, 20], id: \.self) { hours in
                            Button("\(hours):\(24 - hours)") { chosenHours = hours }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(chosenHours == hours ? .white : PM.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(chosenHours == hours ? PM.orange : PM.elevated,
                                            in: Capsule())
                        }
                    }
                }
                Stepper("Custom: \(chosenHours) hours", value: $chosenHours, in: 12...20)
                    .font(.subheadline.weight(.semibold))
                PMLargeButton(title: "START FAST", icon: "timer") {
                    store.startFast(hours: chosenHours)
                }
                Text("You choose your duration. The app never extends a fast automatically.")
                    .font(.caption)
                    .foregroundStyle(PM.secondary)
            }
        }
    }

    @ViewBuilder
    private func activeFastCard(_ fast: FastSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(fast.startedAt))
            let remaining = max(0, fast.goalDate.timeIntervalSince(context.date))
            let stage = FastMilestone.all.last(where: { elapsed >= Double($0.hour) * 3600 }) ?? FastMilestone.all[0]
            let goalReached = remaining <= 0

            VStack(alignment: .leading, spacing: 18) {
                PMPanel {
                    VStack(spacing: 13) {
                        HStack {
                            Text(goalReached ? "FASTING GOAL COMPLETE" : "FASTING IN PROGRESS")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(PM.orange)
                            Spacer()
                            Text("\(fast.targetHours)H GOAL")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PM.secondary)
                        }
                        FastProgressRing(elapsed: elapsed, targetHours: fast.targetHours)
                            .frame(maxWidth: .infinity)
                        Text(goalReached ? "Your eating window can begin." :
                             "\(hoursMinutes(remaining)) remaining until your eating window.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(goalReached ? PM.orangeLight : PM.secondary)
                            .multilineTextAlignment(.center)
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: stage.icon)
                                .font(.title2)
                                .foregroundStyle(stage.color)
                                .frame(width: 40, height: 40)
                                .background(PM.elevated, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(stage.title).font(.headline.weight(.heavy))
                                Text(stage.message)
                                    .font(.subheadline)
                                    .foregroundStyle(PM.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(PM.elevated)
                        Text("Stage markers are general education, not measured ketosis, fat burning or cellular recovery. Actual timing varies.")
                            .font(.caption2)
                            .foregroundStyle(PM.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        PMLargeButton(title: goalReached ? "FINISH FAST" : "END FAST", icon: "checkmark.circle") {
                            if goalReached { store.endFast() }
                            else { showEndConfirmation = true }
                        }
                    }
                }
                milestoneChart(fast: fast, elapsed: elapsed)
            }
        }
    }

    private func milestoneChart(fast: FastSession, elapsed: TimeInterval) -> some View {
        PMPanel {
            VStack(alignment: .leading, spacing: 13) {
                PMSectionTitle(title: "Your fasting milestones")
                ForEach(FastMilestone.all.filter { $0.hour <= fast.targetHours }) { milestone in
                    HStack(spacing: 12) {
                        Image(systemName: milestone.icon)
                            .foregroundStyle(milestone.color)
                            .frame(width: 36, height: 36)
                            .background(PM.elevated, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(milestone.title).font(.subheadline.weight(.bold))
                            Text(milestone.hour == 0 ? "Start · educational guide" :
                                 "Around \(milestone.hour)h · educational guide")
                                .font(.caption2)
                                .foregroundStyle(PM.secondary)
                        }
                        Spacer()
                        Image(systemName: elapsed >= Double(milestone.hour) * 3600 ?
                              "checkmark.circle.fill" : "circle")
                            .foregroundStyle(elapsed >= Double(milestone.hour) * 3600 ?
                                             milestone.color : PM.secondary)
                    }
                }
            }
        }
    }

    private var fastingHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            PMSectionTitle(title: "Recent fasting history", subtitle: "Last 7 sessions")
            let finished = Array(store.fastingSessions.filter { $0.endedAt != nil }
                .sorted { $0.startedAt > $1.startedAt }.prefix(7))
            if finished.isEmpty {
                PMPanel {
                    Text("Your completed fasting sessions will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(PM.secondary)
                }
            } else {
                ForEach(finished) { fast in
                    HStack(spacing: 12) {
                        Image(systemName: fast.completedGoal ? "checkmark.seal.fill" : "clock")
                            .foregroundStyle(fast.completedGoal ? PM.orange : PM.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fast.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.bold))
                            Text("\(fast.targetHours)h target · \(fast.completedGoal ? "Goal reached" : "Ended early")")
                                .font(.caption)
                                .foregroundStyle(PM.secondary)
                        }
                        Spacer()
                        Text(hoursMinutes(fast.duration))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                    .padding(14)
                    .background(PM.surface, in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
    }

    private func hoursMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }
}

private struct FastMilestone: Identifiable {
    let id: Int
    let hour: Int
    let title: String
    let message: String
    let icon: String
    let color: Color

    static let all: [FastMilestone] = [
        .init(id: 0, hour: 0, title: "Glucose for fuel",
              message: "Your body is using available energy from recent meals and stored glucose.",
              icon: "bolt.fill", color: .cyan),
        .init(id: 1, hour: 4, title: "Fat as fuel",
              message: "Your body may be increasing its use of stored fat for energy as fasting continues.",
              icon: "flame.fill", color: PM.orange),
        .init(id: 2, hour: 12, title: "Ketones as fuel",
              message: "As your fast continues, your liver may produce more ketones from fat to provide energy.",
              icon: "sparkles", color: .purple),
        .init(id: 3, hour: 16, title: "Cellular recovery",
              message: "Scientists study cellular maintenance during fasting. A timer cannot tell when these processes start.",
              icon: "leaf.fill", color: PM.green)
    ]
}

private struct FastProgressRing: View {
    let elapsed: TimeInterval
    let targetHours: Int
    private var totalSeconds: Double { Double(targetHours) * 3600 }
    private var progress: Double { min(1, max(0, elapsed / totalSeconds)) }
    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [.cyan, PM.orange, .purple, PM.green, .cyan],
            center: .center
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PM.elevated, lineWidth: 18)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
            VStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(PM.orange)
                Text(timeDisplay(elapsed))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("OF \(targetHours) HOURS")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(PM.secondary)
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(PM.orange)
            }
            ForEach(FastMilestone.all.filter { $0.hour <= targetHours }) { milestone in
                let angle = (Double(milestone.hour) / Double(targetHours) * 360 - 90) * .pi / 180
                Image(systemName: milestone.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(elapsed >= Double(milestone.hour) * 3600 ?
                                     milestone.color : PM.secondary)
                    .frame(width: 33, height: 33)
                    .background(PM.surface, in: Circle())
                    .overlay(Circle().stroke(milestone.color.opacity(0.5), lineWidth: 1))
                    .offset(x: cos(angle) * 132, y: sin(angle) * 132)
            }
        }
        .frame(width: 300, height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PrimalFast progress")
        .accessibilityValue("\(timeDisplay(elapsed)) elapsed of \(targetHours) hours")
    }

    private func timeDisplay(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
