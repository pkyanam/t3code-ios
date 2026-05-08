import SwiftUI

struct MainTabView: View {
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue
    @State private var selectedTab: Tab = .threads

    enum Tab: Hashable {
        case threads
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ThreadsListView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.threads)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(AppAccent.color(for: accentRaw))
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    var body: some View {
        SettingsView(isModal: false)
    }
}
