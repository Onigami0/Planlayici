import Foundation

struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    let completionRate: Double
}

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: Category
    let count: Int
}
