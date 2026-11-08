import SwiftUI

@main
struct PrimalMacroApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.profile == nil {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .tint(PM.orange)
            .background(PM.background)
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
