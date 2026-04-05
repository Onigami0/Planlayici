import SwiftUI
import SwiftData
import PhotosUI

struct NotesView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Note.date, order: .reverse) private var notes: [Note]
    private var audioManager = AudioManager.shared
    
    @State private var showNewNote = false
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        let text = searchText.lowercased()
        let filtered = text.isEmpty ? notes : notes.filter {
            $0.title.lowercased().contains(text) || $0.content.lowercased().contains(text)
        }
        
        // Sort: Pinned first, then by date (already sorted by query, but stable sort preserves it)
        return filtered.sorted { $0.isPinned && !$1.isPinned }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredNotes) { note in
                    NavigationLink {
                        NoteDetailView(note: note)
                    } label: {
                        NoteRow(note: note)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteNotes)
            }
            .listStyle(.plain)
            .navigationTitle("Notlar")
            .searchable(text: $searchText, prompt: "Notlarda ara...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showNewNote = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewNote) {
                NewNoteView()
                    .presentationDetents([.large])
                    .modelContext(modelContext)
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            // Need to map offsets to actual notes in filtered array,
            // but deletion from list view usually works on the indices provided if unfiltered.
            // If filtered, we need to be careful.
            // For safety in this simple implementation with Search,
            // standard ForEach .onDelete might give indices of the FILTERED list.
            
            for index in offsets {
                if index < filteredNotes.count {
                    let note = filteredNotes[index]
                    if let path = note.audioPath {
                        audioManager.deleteRecording(filename: path)
                    }
                    if let imgPath = note.imagePath {
                        ImageManager.shared.deleteImage(filename: imgPath)
                    }
                    modelContext.delete(note)
                }
            }
        }
    }
}

// Custom Row View
struct NoteRow: View {
    let note: Note
    
    var noteColor: Color {
        switch note.noteColor {
        case "red": return .red.opacity(0.15)
        case "orange": return .orange.opacity(0.15)
        case "yellow": return .yellow.opacity(0.15)
        case "green": return .green.opacity(0.15)
        case "purple": return .purple.opacity(0.15)
        default: return .blue.opacity(0.1)
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    if note.audioPath != nil {
                        Label("Ses", systemImage: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if note.imagePath != nil {
                        Label("Görsel", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(noteColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
    }
}


struct NewNoteView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @ObservedObject private var audioManager = AudioManager.shared
    
    @State private var title = ""
    @State private var content = ""
    @State private var isPinned = false
    @State private var selectedColor = "blue"
    
    // Audio
    @State private var isRecording = false
    @State private var recordedFilename: String?
    
    // Image
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    let colors = ["blue", "purple", "green", "yellow", "orange", "red"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Başlık", text: $title)
                        .font(.headline)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
                
                Section("Görünüm ve Sabitleme") {
                    Toggle("En Üste Sabitle", systemImage: "pin", isOn: $isPinned)
                        .tint(.orange)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(colors, id: \.self) { colorName in
                                Circle()
                                    .fill(getColor(name: colorName))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == colorName ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = colorName
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section("Medya") {
                    // Photo Picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let selectedImage {
                            HStack {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text("Görseli Değiştir")
                            }
                        } else {
                            Label("Fotoğraf Ekle", systemImage: "photo")
                        }
                    }
                    .onChange(of: selectedItem) {
                        Task {
                            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = uiImage
                            }
                        }
                    }
                    
                    // Audio Recorder
                    if isRecording {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse)
                            Text("Kaydediliyor... \(String(format: "%.1f", audioManager.recordingTime))s")
                            Spacer()
                            Button("Durdur") {
                                audioManager.stopRecording()
                                isRecording = false
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        if let filename = recordedFilename {
                            HStack {
                                Label("Ses Kaydı Eklendi", systemImage: "mic.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Button("Sil", role: .destructive) {
                                    audioManager.deleteRecording(filename: filename)
                                    recordedFilename = nil
                                }
                            }
                        } else {
                            Button {
                                audioManager.requestPermission()
                                let filename = UUID().uuidString + ".m4a"
                                if audioManager.startRecording(filename: filename) != nil {
                                    recordedFilename = filename
                                    isRecording = true
                                }
                            } label: {
                                Label("Ses Kaydı Başlat", systemImage: "mic")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yeni Not")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        if let filename = recordedFilename {
                            audioManager.deleteRecording(filename: filename)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveNote()
                        dismiss()
                    }
                }
            }
        }
    }
    
    func saveNote() {
        // Ensure recording is stopped and saved
        if isRecording {
            audioManager.stopRecording()
            isRecording = false
        }
        
        var imagePath: String? = nil
        if let selectedImage {
            imagePath = ImageManager.shared.saveImage(selectedImage)
        }
        
        let note = Note(
            title: title.isEmpty ? "Adsız Not" : title,
            content: content,
            audioPath: recordedFilename,
            imagePath: imagePath,
            isPinned: isPinned,
            noteColor: selectedColor
        )
        modelContext.insert(note)
    }
    
    func getColor(name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        default: return .blue
        }
    }
}

struct NoteDetailView: View {
    @Bindable var note: Note
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var showShare = false
    @State private var showDeleteConfirmation = false
    
    let colors = ["blue", "purple", "green", "yellow", "orange", "red"]
    
    var body: some View {
        Form {
            Section {
                TextField("Başlık", text: $note.title)
                    .font(.headline)
                TextEditor(text: $note.content)
                    .frame(minHeight: 150)
            }
            
            Section("Ayarlar") {
                Toggle("En Üste Sabitle", isOn: $note.isPinned)
                    .tint(.orange)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(colors, id: \.self) { colorName in
                            Circle()
                                .fill(getColor(name: colorName))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: note.noteColor == colorName ? 2 : 0)
                                )
                                .onTapGesture {
                                    note.noteColor = colorName
                                }
                        }
                    }
                }
            }
            
            Section("Medya") {
                // Image Display
                if let imagePath = note.imagePath, let uiImage = ImageManager.shared.loadImage(filename: imagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                        .contextMenu {
                            Button("Resmi Sil", role: .destructive) {
                                ImageManager.shared.deleteImage(filename: imagePath)
                                note.imagePath = nil
                            }
                        }
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(note.imagePath == nil ? "Fotoğraf Ekle" : "Fotoğrafı Değiştir", systemImage: "photo")
                }
                .onChange(of: selectedItem) {
                    Task {
                        if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            // Delete old image if exists
                            if let oldPath = note.imagePath {
                                ImageManager.shared.deleteImage(filename: oldPath)
                            }
                            // Save new
                            note.imagePath = ImageManager.shared.saveImage(uiImage)
                        }
                        selectedItem = nil // Reset
                    }
                }
                
                // Audio Player
                if let audioPath = note.audioPath {
                    HStack {
                        let isPlayingThis = audioManager.isPlaying && audioManager.currentPlayingFilename == audioPath
                        
                        Button {
                            if isPlayingThis {
                                audioManager.stopPlaying()
                            } else {
                                audioManager.startPlaying(filename: audioPath)
                            }
                        } label: {
                            Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                        .buttonStyle(.borderless) // Prevent tap conflict
                        
                        Text(isPlayingThis ? "Çalınıyor..." : "Ses Kaydı")
                        
                        Spacer()
                        
                        Button("Sil", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .alert("Ses Kaydını Sil", isPresented: $showDeleteConfirmation) {
                            Button("Sil", role: .destructive) {
                                audioManager.deleteRecording(filename: audioPath)
                                note.audioPath = nil
                            }
                            Button("İptal", role: .cancel) { }
                        } message: {
                            Text("Bu ses kaydını silmek istediğinize emin misiniz?")
                        }
                    }
                }
            }
        }
        .navigationTitle("Detay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
             ToolbarItem(placement: .primaryAction) {
                 Button(action: { showShare = true }) {
                     Image(systemName: "square.and.arrow.up")
                 }
             }
         }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: prepareShareItems())
                .presentationDetents([.medium, .large])
        }
        .onDisappear {
            audioManager.stopPlaying()
        }
    }
    
    func prepareShareItems() -> [Any] {
        var items: [Any] = []
        // Share text content (Title + Content)
        let textToShare = "\(note.title)\n\n\(note.content)"
        items.append(textToShare)
        
        // Share Image if exists
        if let imagePath = note.imagePath,
           let image = ImageManager.shared.loadImage(filename: imagePath) {
            items.append(image)
        }
        
        // Share Audio if exists
        if let audioPath = note.audioPath {
            let audioUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(audioPath)
            items.append(audioUrl)
        }
        
        return items
    }
    
    func getColor(name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        default: return .blue
        }
    }
}

// Custom Share Sheet to handle mixed content (Text + Audio/Image) better than ShareLink
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

