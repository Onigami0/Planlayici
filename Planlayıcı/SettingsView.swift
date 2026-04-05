import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("appThemeColor") private var appThemeColor = "blue"
    @AppStorage("morningNotification") private var morningNotification = false
    @AppStorage("eveningNotification") private var eveningNotification = false
    
    let colors = ["blue", "purple", "green", "orange", "red", "pink"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Görünüm") {
                    Toggle("Karanlık Mod", isOn: $isDarkMode)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(getColor(name: color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: appThemeColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        withAnimation {
                                            appThemeColor = color
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section("Bildirimler") {
                    Toggle("Sabah Özeti (08:00)", isOn: $morningNotification)
                        .onChange(of: morningNotification) { oldValue, newValue in
                            NotificationManager.shared.toggleMorningSummary(enabled: newValue)
                        }
                    
                    Toggle("Akşam Raporu (22:00)", isOn: $eveningNotification)
                        .onChange(of: eveningNotification) { oldValue, newValue in
                            NotificationManager.shared.toggleEveningReport(enabled: newValue)
                        }
                }
                
                Section("Diğer") {
                    NavigationLink(destination: StatisticsView()) {
                        Label("İstatistikler", systemImage: "chart.bar.xaxis")
                    }
                }
                
                Section("Hakkında") {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        Text("1.1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
    
    private func getColor(name: String) -> Color {
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

