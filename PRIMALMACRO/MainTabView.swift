import SwiftUI

enum PMTab: Hashable {
    case home, diary, scan, progress, plan
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: PMTab = .home

    var body: some View {
        TabView(selection: $selected) {
            HomeView(openScanner: { selected = .scan }, openDiary: { selected = .diary })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(PMTab.home)
            DiaryView()
                .tabItem { Label("Diary", systemImage: "list.bullet.rectangle") }
                .tag(PMTab.diary)
            ScannerView()
                .tabItem { Label("Scan", systemImage: "camera.fill") }
                .tag(PMTab.scan)
            if store.profile?.isAdult == true {
                WeightProgressView()
                    .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                    .tag(PMTab.progress)
            }
            PlanView()
                .tabItem { Label("Plan", systemImage: "slider.horizontal.3") }
                .tag(PMTab.plan)
        }
        .toolbarBackground(PM.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
