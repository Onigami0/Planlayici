import SwiftUI
import SwiftData

struct DailyPlannerView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var tasks: [PlannerTask]
    @State private var viewModel = PlannerViewModel()
    
    @State private var selectedDate = Date()
    @State private var visibleWeekStart: Date = Date() // Track the start of the currently visible week
    @State private var showAddTask = false
    
    // Sort tasks by completion (pending first) and then by time/priority if needed
    var filteredTasks: [PlannerTask] {
        let calendar = Calendar.current
        return tasks.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted {
                if $0.isCompleted == $1.isCompleted {
                    return $0.date < $1.date // Sort by creation/target time roughly
                }
                return !$0.isCompleted && $1.isCompleted // Pending first
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                 // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Weekly Calendar Header
                    WeeklySwipeView(visibleWeekStart: $visibleWeekStart, selectedDate: $selectedDate)
                        .background(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    
                    // Content
                    if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Progress Section
                                progressSection
                                
                                // Task List
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredTasks) { task in
                                        TaskCard(task: task, viewModel: viewModel)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                            .padding(.top)
                        }
                    }
                }
            }
            .navigationTitle(visibleWeekStart.formatted(.dateTime.month(.wide).year())) // Dynamic Title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                }
                
                // Button to jump back to Today
                ToolbarItem(placement: .topBarLeading) {
                    Button("Bugün") {
                        let today = Date()
                        selectedDate = today
                        visibleWeekStart = today.startOfWeek
                    }
                }
            }
            .onAppear {
                viewModel.modelContext = modelContext
                // Initialize visible week to current week start on first load
                if visibleWeekStart == Date.distantPast { // Or some check, but simple assignment is fine
                     visibleWeekStart = Date().startOfWeek
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(viewModel: viewModel)
            }
        }
    }
    
    // Existing progress section...
    private var progressSection: some View {
        let progress = viewModel.completionProgress(for: filteredTasks)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("İlerleme")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * progress)
                        .animation(.spring, value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(.gray.opacity(0.3))
            
            Text("Bu gün için plan yok")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

// Swipeable Weekly View
struct WeeklySwipeView: View {
    @Binding var visibleWeekStart: Date
    @Binding var selectedDate: Date
    
    // Gesture State
    @State private var dragOffset: CGFloat = 0
    
    var weekDays: [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: visibleWeekStart) {
                days.append(date)
            }
        }
        return days
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(date.formatted(.dateTime.day()))
                        .font(.headline)
                        .fontWeight(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                        .foregroundStyle(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.blue : Color.clear)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 30) // Prevent blocking taps
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring) {
                        if value.translation.width > threshold {
                            // Swipe Right -> Previous Week
                            visibleWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: visibleWeekStart) ?? visibleWeekStart
                        } else if value.translation.width < -threshold {
                            // Swipe Left -> Next Week
                            visibleWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: visibleWeekStart) ?? visibleWeekStart
                        }
                        dragOffset = 0
                    }
                }
        )
    }
}

// Helpers
extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: self)
        let weekday = calendar.component(.weekday, from: today)
        // Adjust for Monday start: Sunday(1) -> 6, Monday(2) -> 0
        let daysToSubtract = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? self
    }
}

// Keep TaskCard as is, but duplicate here if replacing whole file.
// Since we are writing the whole file, we must include it.
struct TaskCard: View {
    @Bindable var task: PlannerTask
    var viewModel: PlannerViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleCompletion(for: task)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(task.isCompleted ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted, color: .gray)
                    .foregroundStyle(task.isCompleted ? .gray : .primary)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                            .font(.caption2)
                        Text(task.category.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(task.category.color.opacity(0.2))
                    .foregroundStyle(task.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if let notificationTime = task.notificationTime {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                            Text(notificationTime.formatted(date: .omitted, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    if task.priority == .high && !task.isCompleted {
                         Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                Button(role: .destructive) {
                    withAnimation {
                         viewModel.deleteTask(task: task)
                    }
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .opacity(task.isCompleted ? 0.7 : 1.0)
    }
}

