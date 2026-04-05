import Foundation
import SwiftData
import SwiftUI

@Observable
class PlannerViewModel {
    var modelContext: ModelContext?
    
    init() { }
    
    func addTask(title: String, note: String?, date: Date, priority: Priority, category: Category, notificationTime: Date?, soundName: String = "tri-tone", context: ModelContext) {
        
        let newTask = PlannerTask(title: title, note: note, date: date, priority: priority, category: category, notificationTime: notificationTime, soundName: soundName)
        context.insert(newTask)
        
        if notificationTime != nil {
            NotificationManager.shared.scheduleNotification(for: newTask)
        }
    }
    
    func deleteTask(task: PlannerTask) {
        // Fallback to internal context if needed, but better to pass it.
        // For deletion from list (Swipe), we usually get context from valid view hierarchy.
        // We will assume Delete is called from a view where context is valid or we should update logic.
        // For now, let's keep the existing logic but be safe.
        guard let context = modelContext else { return }
        NotificationManager.shared.cancelNotification(for: task)
        context.delete(task)
    }
    
    func toggleCompletion(for task: PlannerTask) {
        task.isCompleted.toggle()
        
        if task.isCompleted {
            NotificationManager.shared.cancelNotification(for: task)
        } else if task.notificationTime != nil {
            NotificationManager.shared.scheduleNotification(for: task)
        }
    }
    
    func completionProgress(for tasks: [PlannerTask]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    // MARK: - Statistics
    
    // Structs moved to StatisticsModels.swift
    
    func getWeeklyStats(tasks: [PlannerTask]) -> [DailyStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var stats: [DailyStat] = []
        
        // Last 7 days
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let daysTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let rate = completionProgress(for: daysTasks)
                stats.append(DailyStat(date: date, completionRate: rate))
            }
        }
        return stats.reversed()
    }
    
    func getCategoryStats(tasks: [PlannerTask]) -> [CategoryStat] {
        var counts: [Category: Int] = [:]
        for task in tasks {
            counts[task.category, default: 0] += 1
        }
        
        return counts.map { CategoryStat(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

