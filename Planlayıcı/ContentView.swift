import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    // init removed to use default system appearance


    var body: some View {
        TabView(selection: $selectedTab) {
            DailyPlannerView()
                .tabItem {
                    Label("Günün Planı", systemImage: "list.bullet.clipboard")
                }
                .tag(0)
            
            MonthlyCalendarView()
                .tabItem {
                    Label("Takvim", systemImage: "calendar")
                }
                .tag(1)
            
            NotesView()
                .tabItem {
                    Label("Notlar", systemImage: "note.text")
                }
                .tag(2)
            
            StatisticsView()
                .tabItem {
                    Label("İstatistik", systemImage: "chart.bar.xaxis")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Ayarlar", systemImage: "gear")
                }
                .tag(4)
        }


        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("didTapReportNotification"))) { _ in
            selectedTab = 3 // Switch to Statistics tab
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("didTapMorningSummary"))) { _ in
            selectedTab = 0 // Switch to Daily Planner tab
        }
    }
}

