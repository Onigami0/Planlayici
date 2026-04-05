import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var date: Date
    var audioPath: String?
    var imagePath: String?
    var isPinned: Bool = false
    var noteColor: String = "blue"
    
    init(id: UUID = UUID(),
         title: String,
         content: String,
         date: Date = Date(),
         audioPath: String? = nil,
         imagePath: String? = nil,
         isPinned: Bool = false,
         noteColor: String = "blue") {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.audioPath = audioPath
        self.imagePath = imagePath
        self.isPinned = isPinned
        self.noteColor = noteColor
    }
}

