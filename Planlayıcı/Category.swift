import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
    case personal = "Kişisel"
    case work = "İş"
    case home = "Ev"
    case health = "Sağlık"
    case other = "Diğer"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .work: return "briefcase.fill"
        case .home: return "house.fill"
        case .health: return "heart.fill"
        case .other: return "tag.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .personal: return .blue
        case .work: return .purple
        case .home: return .orange
        case .health: return .red
        case .other: return .gray
        }
    }
}

