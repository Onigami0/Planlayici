import SwiftUI
import SwiftData

struct MonthlyCalendarView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var tasks: [PlannerTask]
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    
    private let daysOfWeek = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar Header
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .padding()
                            .background(Circle().fill(Color(UIColor.secondarySystemGroupedBackground)))
                    }
                    
                    Spacer()
                    
                    Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        // Turkish Locale override if device thinks strictly English,
                        // but usually system locale works. To force Turkish:
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                    
                    Spacer()
                    
                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .padding()
                            .background(Circle().fill(Color(UIColor.secondarySystemGroupedBackground)))
                    }
                }
                .padding()
                
                // Days Row
                HStack {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)
                
                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                    ForEach(extractDates(), id: \.self) { date in
                         if let date = date {
                             DayCell(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate), indicatorColor: getPriorityColor(for: date))
                                 .onTapGesture {
                                     withAnimation {
                                         selectedDate = date
                                     }
                                 }
                         } else {
                             Color.clear.frame(height: 40)
                         }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                .padding(.horizontal)
                
                // Selected Date Tasks
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(selectedDate.formatted(.dateTime.day().month(.wide))) Planları")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    let dailyTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
                    
                    if dailyTasks.isEmpty {
                        Spacer()
                        ContentUnavailableView("Etkinlik Yok", systemImage: "calendar.badge.minus")
                        Spacer()
                    } else {
                        List(dailyTasks) { task in
                            HStack {
                                Circle()
                                    .fill(task.category.color)
                                    .frame(width: 8, height: 8)
                                    
                                VStack(alignment: .leading) {
                                    Text(task.title)
                                        .strikethrough(task.isCompleted)
                                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                    if let time = task.notificationTime {
                                        Text(time.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if task.isCompleted {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Takvim")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func extractDates() -> [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        
        let dayOfWeek = calendar.component(.weekday, from: monthStart)
        // Adjust for Monday start (Swift Sunday=1, Monday=2)
        // If Monday start (2) -> offset 0
        // Sunday (1) -> offset 6
        let startingSpaces = (dayOfWeek + 5) % 7
        
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        
        var days: [Date?] = Array(repeating: nil, count: startingSpaces)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func getPriorityColor(for date: Date) -> Color? {
        let dailyTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        if dailyTasks.isEmpty { return nil }
        
        if dailyTasks.contains(where: { $0.priority == .high }) {
            return .red
        } else if dailyTasks.contains(where: { $0.priority == .medium }) {
            return .orange
        } else {
            return .green
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let indicatorColor: Color?
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.body)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 35, height: 35)
                .background(isSelected ? Circle().fill(Color.blue) : Circle().fill(Color.clear))
            
            if let color = indicatorColor {
                Circle()
                    .fill(isSelected ? .white : color)
                    .frame(width: 5, height: 5)
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 45)
    }
}

