import SwiftUI
import SwiftData

@main
struct PlannerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlannerTask.self,
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // Request notification permission on app launch
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    @AppStorage("appThemeColor") private var appThemeColor = "blue"
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .tint(getColor(name: appThemeColor))
        }
        .modelContainer(sharedModelContainer)
    }
    
    func getColor(name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
}

