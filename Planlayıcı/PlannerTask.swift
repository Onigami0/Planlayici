import Foundation
import SwiftData

@Model
final class PlannerTask {
    var id: UUID
    var title: String
    var note: String?
    var date: Date
    var isCompleted: Bool
    var priority: Priority
    var category: Category
    var notificationTime: Date?
    var soundName: String = "tri-tone" // Default sound
    
    init(id: UUID = UUID(),
         title: String,
         note: String? = nil,
         date: Date = Date(),
         isCompleted: Bool = false,
         priority: Priority = .medium,
         category: Category = .personal,
         notificationTime: Date? = nil,
         soundName: String = "tri-tone") {
        self.id = id
        self.title = title
        self.note = note
        self.date = date
        self.isCompleted = isCompleted
        self.priority = priority
        self.category = category
        self.notificationTime = notificationTime
        self.soundName = soundName
    }
}

