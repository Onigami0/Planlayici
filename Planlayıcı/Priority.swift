import SwiftUI

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Düşük"
    case medium = "Orta"
    case high = "Yüksek"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "exclamationmark.3"
        }
    }
}

