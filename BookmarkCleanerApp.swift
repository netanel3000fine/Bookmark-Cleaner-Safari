import SwiftUI


@main
struct BookmarkCleanerApp: App {
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1100, minHeight: 700)
                .tint(themeColor.color)
        }
        .windowToolbarStyle(.unifiedCompact)
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}
