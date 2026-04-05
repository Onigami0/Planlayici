import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var tasks: [PlannerTask]
    @State private var viewModel = PlannerViewModel()
    @State private var selectedStatType: StatType = .weekly
    
    // Data for charts
    @State private var weeklyStats: [DailyStat] = []
    @State private var categoryStats: [CategoryStat] = []
    
    enum StatType: String, CaseIterable, Identifiable {
        case weekly = "Haftalık Verim"
        case category = "Kategori Dağılımı"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Highlights
                    HStack(spacing: 16) {
                        MetricCard(title: "Toplam Görev", value: "\(tasks.count)", icon: "list.bullet.clipboard", color: .blue)
                        MetricCard(title: "Tamamlanan", value: "\(tasks.filter(\.isCompleted).count)", icon: "checkmark.circle.fill", color: .green)
                    }
                    .padding(.horizontal)
                    
                    // Picker
                    Picker("İstatistik Türü", selection: $selectedStatType) {
                        ForEach(StatType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Charts
                    VStack(alignment: .leading) {
                        chartsView
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                    
                    if tasks.isEmpty {
                         Text("Henüz yeterli veri yok.")
                             .foregroundStyle(.secondary)
                             .padding()
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("İstatistikler")
            .onAppear(perform: updateStats)
            .onChange(of: tasks, updateStats)
        }
    }
    
    func updateStats() {
        weeklyStats = viewModel.getWeeklyStats(tasks: tasks)
        categoryStats = viewModel.getCategoryStats(tasks: tasks)
    }
    
    @ViewBuilder
    var chartsView: some View {
        if selectedStatType == .weekly {
            Text("Son 7 Günlük Tamamlanma Oranı")
                .font(.headline)
                .padding(.bottom, 8)
            
            Chart(weeklyStats) { stat in
                BarMark(
                    x: .value("Gün", stat.date.formatted(.dateTime.weekday(.abbreviated))),
                    y: .value("Oran", stat.completionRate * 100)
                )
                .foregroundStyle(Color.blue.gradient)
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(1))
            }
        } else {
            Text("Görevlerin Kategorilere Göre Dağılımı")
                .font(.headline)
                .padding(.bottom, 8)
            
            Chart(categoryStats) { stat in
                SectorMark(
                    angle: .value("Sayı", stat.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Kategori", stat.category.rawValue))
                .cornerRadius(5)
            }
            .frame(height: 250)
            .chartLegend(position: .bottom, spacing: 20)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

