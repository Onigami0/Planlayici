import UserNotifications
import Foundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("Bildirim izni hatası: \(error.localizedDescription)")
            } else {
                print("Bildirim izni: \(success)")
            }
        }
    }
    
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        print("DEBUG: Notification tapped with identifier: \(identifier)")
        
        if identifier == "morning_summary" {
            print("DEBUG: Posting didTapMorningSummary signal")
            NotificationCenter.default.post(name: NSNotification.Name("didTapMorningSummary"), object: nil)
        } else if identifier == "evening_report" || identifier == "evening_report_dynamic" {
            print("DEBUG: Posting didTapReportNotification signal")
            // Post signal to open Statistics tab
            NotificationCenter.default.post(name: NSNotification.Name("didTapReportNotification"), object: nil)
        } else {
            print("DEBUG: Identifier did not match summary reports")
        }
        
        completionHandler()
    }
    
    func scheduleNotification(for task: PlannerTask) {
        // Remove existing notification for this task to avoid duplicates
        cancelNotification(for: task)
        
        guard let notificationTime = task.notificationTime, !task.isCompleted else { return }
        
        // Ensure notification time is in the future
        guard notificationTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Hatırlatıcı: \(task.title)"
        if let note = task.note, !note.isEmpty {
            content.body = note
        }
        
        // Sound handling
        if task.soundName == "default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: task.soundName + ".caf"))
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Bildirim zamanlama hatası: \(error.localizedDescription)")
            } else {
                print("Bildirim zamanlandı: \(task.title) - \(notificationTime.formatted())")
            }
        }
    }
    
    func cancelNotification(for task: PlannerTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    // MARK: - Daily Reports
    
    func scheduleDailyReport(at hour: Int, minute: Int, title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func toggleMorningSummary(enabled: Bool) {
        if enabled {
            scheduleDailyReport(at: 8, minute: 0, title: "Günaydın! ☀️", body: "Bugünkü planlarını gözden geçirmek ister misin?", identifier: "morning_summary")
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_summary"])
        }
    }
    
    func toggleEveningReport(enabled: Bool) {
        if enabled {
            scheduleDailyReport(at: 22, minute: 0, title: "Günün Özeti 🌙", body: "Bugün neler başardın? Hadi kontrol edelim.", identifier: "evening_report")
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_report"])
        }
    }
    func scheduleDynamicEveningReport(completed: Int, remaining: Int) {
        // Check if feature is enabled in UserDefaults (to respect the toggle)
        guard UserDefaults.standard.bool(forKey: "eveningNotification") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Günün Özeti 🌙"
        
        if remaining == 0 && completed > 0 {
            content.body = "Tebrikler! 🎉 Bugün planladığın \(completed) görevin hepsini tamamladın."
        } else if completed == 0 && remaining == 0 {
            content.body = "Bugün için planlanmış bir görevin yoktu. Yarın için plan yapmak ister misin?"
        } else {
            content.body = "Bugün \(completed) görev tamamlandı, \(remaining) görev seni bekliyor."
        }
        
        content.sound = .default
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 22
        dateComponents.minute = 0
        
        // If it's already past 22:00, this won't fire for today, which is correct.
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "evening_report_dynamic", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleDynamicMorningSummary(count: Int, for date: Date) {
        // Check toggle
        guard UserDefaults.standard.bool(forKey: "morningNotification") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Günaydın! ☀️"
        
        if count == 0 {
            content.body = "Bugün için planlanmış bir görevin yok. Keyfine bak! ☕️"
        } else {
            content.body = "Bugün seni bekleyen \(count) görev var. Harika bir gün olsun! 💪"
        }
        
        content.sound = .default
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        // Same identifier as the static one to overwrite it
        let request = UNNotificationRequest(identifier: "morning_summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendInstantNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

