import SwiftUI
import SwiftData

@main
struct CortexApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Bookmark.self, Tag.self])
    }
}

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some View {
        Group {
            if authManager.showingAuthenticationView {
                AuthenticationView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.showingAuthenticationView)
        .preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }

            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .background {
            LinearGradient(
                colors: [
                    CortexColors.primary.deepSpace,
                    CortexColors.primary.darkBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
