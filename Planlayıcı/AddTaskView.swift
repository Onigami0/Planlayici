import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    var viewModel: PlannerViewModel
    
    @State private var title = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var priority: Priority = .medium
    @State private var category: Category = .personal
    @State private var shouldRemind = false
    @State private var reminderTime = Date()

    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Görev Adı", text: $title)
                        .font(.headline)
                    
                    TextField("Not (İsteğe bağlı)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("Göreviniz için kısa bir başlık ve detay ekleyin.")
                }
                
                Section("Detaylar") {
                    Picker("Kategori", selection: $category) {
                        ForEach(Category.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    Picker("Öncelik", selection: $priority) {
                        ForEach(Priority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.icon)
                                .foregroundStyle(priority.color)
                                .tag(priority)
                        }
                    }
                }
                
                Section("Zamanlama") {
                    DatePicker("Tarih", selection: $date, displayedComponents: [.date])
                    
                    Toggle("Alarm Kur", isOn: $shouldRemind)
                        .tint(.blue)
                    
                    if shouldRemind {
                        DatePicker("Saat", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                        

                    }
                }
            }
            .navigationTitle("Yeni Görev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        let notificationTime = shouldRemind ? combineDate(date, time: reminderTime) : nil
                        viewModel.addTask(title: title, note: note.isEmpty ? nil : note, date: date, priority: priority, category: category, notificationTime: notificationTime, context: modelContext)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func combineDate(_ date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        return calendar.date(from: DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day, hour: timeComponents.hour, minute: timeComponents.minute)) ?? date
    }
}

