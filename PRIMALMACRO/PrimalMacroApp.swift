import SwiftUI

@main
struct PrimalMacroApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var member = AppleMemberSession()
    @StateObject private var plans = MembershipPlans()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MembershipGateView()
                .environmentObject(store)
                .environmentObject(member)
                .environmentObject(plans)
                .preferredColorScheme(.dark)
                .tint(PM.orange)
                .background { PM.background.ignoresSafeArea() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await member.restore()
                            await plans.refreshEntitlement()
                        }
                    }
                }
                .alert("Save problem", isPresented: Binding(
                    get: { store.persistenceError != nil },
                    set: { if !$0 { store.persistenceError = nil } }
                )) {
                    Button("OK") { store.persistenceError = nil }
                } message: {
                    Text(store.persistenceError ?? "")
                }
        }
    }
}
