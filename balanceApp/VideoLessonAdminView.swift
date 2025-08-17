import SwiftUI
import PhotosUI
import AVKit
import AppMetricaCore

struct VideoLessonAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VideoLessonViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category = ""
    @State private var instructor = ""
    @State private var duration = ""
    
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var selectedThumbnailItem: PhotosPickerItem? = nil
    @State private var videoUrl: String?
    @State private var thumbnailUrl: String?
    
    @State private var isUploadingVideo = false
    @State private var isUploadingThumbnail = false
    @State private var uploadProgress: Double = 0
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основная информация")) {
                    TextField("Название видео урока", text: $title)
                    TextField("Описание", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Цена (₽)", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Категория", text: $category)
                    TextField("Инструктор", text: $instructor)
                    TextField("Длительность (секунды)", text: $duration)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Видео файл")) {
                    PhotosPicker(selection: $selectedVideoItem, matching: .videos, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "video")
                            Text(videoUrl != nil ? "Видео выбрано" : "Выбрать видео")
                        }
                    }
                    
                    if isUploadingVideo {
                        VStack {
                            ProgressView(value: uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text("Загрузка видео: \(Int(uploadProgress * 100))%")
                                .font(.caption)
                        }
                    }
                    
                    if let videoUrl = videoUrl {
                        Text("Видео загружено")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("Превью (опционально)")) {
                    PhotosPicker(selection: $selectedThumbnailItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo")
                            Text(thumbnailUrl != nil ? "Превью выбрано" : "Выбрать превью")
                        }
                    }
                    
                    if isUploadingThumbnail {
                        ProgressView("Загрузка превью...")
                    }
                    
                    if let thumbnailUrl = thumbnailUrl {
                        Text("Превью загружено")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button("Добавить видео урок") {
                        addVideoLesson()
                    }
                    .disabled(!canAddVideoLesson)
                }
            }
            .navigationTitle("Новый видео урок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedVideoItem) { _, newItem in
            handleVideoSelection(newItem)
        }
        .onChange(of: selectedThumbnailItem) { _, newItem in
            handleThumbnailSelection(newItem)
        }
        .alert("Ошибка", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canAddVideoLesson: Bool {
        !title.isEmpty && 
        !description.isEmpty && 
        !price.isEmpty && 
        !category.isEmpty && 
        !instructor.isEmpty && 
        videoUrl != nil
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isUploadingVideo = true
        uploadProgress = 0
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data?):
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mov")
                try? data.write(to: tmpURL)
                
                viewModel.uploadVideo(fileURL: tmpURL, progress: { progress in
                    DispatchQueue.main.async {
                        self.uploadProgress = progress
                    }
                }, completion: { result in
                    DispatchQueue.main.async {
                        self.isUploadingVideo = false
                        switch result {
                        case .success(let url):
                            self.videoUrl = url
                        case .failure(let error):
                            self.alertMessage = "Ошибка загрузки видео: \(error.localizedDescription)"
                            self.showingAlert = true
                        }
                    }
                })
            default:
                DispatchQueue.main.async {
                    self.isUploadingVideo = false
                    self.alertMessage = "Ошибка обработки видео"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func handleThumbnailSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isUploadingThumbnail = true
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data?):
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".jpg")
                try? data.write(to: tmpURL)
                
                viewModel.uploadThumbnail(fileURL: tmpURL) { result in
                    DispatchQueue.main.async {
                        self.isUploadingThumbnail = false
                        switch result {
                        case .success(let url):
                            self.thumbnailUrl = url
                        case .failure(let error):
                            self.alertMessage = "Ошибка загрузки превью: \(error.localizedDescription)"
                            self.showingAlert = true
                        }
                    }
                }
            default:
                DispatchQueue.main.async {
                    self.isUploadingThumbnail = false
                    self.alertMessage = "Ошибка обработки превью"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func addVideoLesson() {
        guard let videoUrl = videoUrl,
              let priceInt = Int(price),
              let durationInt = Int(duration) else {
            alertMessage = "Проверьте правильность введенных данных"
            showingAlert = true
            return
        }
        
        let lesson = VideoLesson(
            id: UUID().uuidString,
            title: title,
            description: description,
            price: priceInt,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            duration: durationInt,
            category: category,
            instructor: instructor,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        viewModel.addVideoLesson(lesson) { success in
            if success {
                AppMetrica.reportEvent(name: "Админ добавил видео урок", parameters: [
                    "video_title": lesson.title,
                    "price": lesson.price,
                    "category": lesson.category ?? ""
                ])
                dismiss()
            } else {
                alertMessage = "Ошибка добавления видео урока"
                showingAlert = true
            }
        }
    }
}

// MARK: - Список видео уроков для админа

struct VideoLessonListAdminView: View {
    @ObservedObject var viewModel: VideoLessonViewModel
    @State private var showingAddVideo = false
    @State private var lessonToDelete: VideoLesson?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.videoLessons) { lesson in
                    VideoLessonAdminRowView(lesson: lesson, viewModel: viewModel)
                        .contextMenu {
                            Button("Редактировать") {
                                // Открываем редактирование через VideoLessonAdminRowView
                            }
                            Button(lesson.isActive ? "Деактивировать" : "Активировать") {
                                toggleLessonActive(lesson)
                            }
                            if lesson.hasActiveDiscount {
                                Button("Убрать скидку") {
                                    removeDiscount(lesson)
                                }
                            }
                            Button("Удалить", role: .destructive) {
                                lessonToDelete = lesson
                                showingDeleteAlert = true
                            }
                        }
                }
            }
            .navigationTitle("Управление видео уроками")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddVideo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddVideo) {
            VideoLessonAdminView(viewModel: viewModel)
        }
        .alert("Удалить видео урок?", isPresented: $showingDeleteAlert, presenting: lessonToDelete) { lesson in
            Button("Удалить", role: .destructive) {
                deleteLesson(lesson)
            }
            Button("Отмена", role: .cancel) { }
        } message: { lesson in
            Text("Видео урок \"\(lesson.title)\" будет удален безвозвратно.")
        }
    }
    
    private func toggleLessonActive(_ lesson: VideoLesson) {
        viewModel.toggleVideoLessonActive(lesson.id) { success in
            if success {
                AppMetrica.reportEvent(name: "Админ изменил статус видео урока", parameters: [
                    "video_title": lesson.title,
                    "new_status": lesson.isActive ? "active" : "inactive"
                ])
            }
        }
    }
    
    private func deleteLesson(_ lesson: VideoLesson) {
        viewModel.deleteVideoLesson(lesson.id) { success in
            if success {
                AppMetrica.reportEvent(name: "Админ удалил видео урок", parameters: [
                    "video_title": lesson.title
                ])
            }
        }
    }
    
    private func removeDiscount(_ lesson: VideoLesson) {
        viewModel.removeDiscountFromLesson(lessonId: lesson.id) { success in
            if success {
                AppMetrica.reportEvent(name: "Админ убрал скидку с видео урока", parameters: [
                    "video_title": lesson.title
                ])
            }
        }
    }
}

// MARK: - Строка видео урока для админа

struct VideoLessonAdminRowView: View {
    let lesson: VideoLesson
    @ObservedObject var viewModel: VideoLessonViewModel
    @State private var showingEditView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.instructor ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Цена с учетом скидки
                    if lesson.hasActiveDiscount {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(viewModel.formatPrice(lesson.currentPrice))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                
                                Text("-\(lesson.discountPercentage ?? 0)%")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(3)
                            }
                            
                            Text(viewModel.formatPrice(lesson.originalPrice))
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.secondary)
                            
                            // Таймер обратного отсчета
                            if let discount = lesson.discount {
                                DiscountTimerView(endDate: discount.endDate)
                            }
                        }
                    } else {
                        Text(viewModel.formatPrice(lesson.currentPrice))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Circle()
                            .fill(lesson.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(lesson.isActive ? "Активен" : "Неактивен")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(lesson.description)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            HStack {
                if let category = lesson.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let duration = lesson.duration {
                    Text(viewModel.formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Редактировать") {
                    showingEditView = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                if let createdAt = lesson.createdAt {
                    Text(formatDate(createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditView) {
            VideoLessonEditView(lesson: lesson, viewModel: viewModel)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct VideoLessonAdminView_Previews: PreviewProvider {
    static var previews: some View {
        VideoLessonAdminView(viewModel: VideoLessonViewModel())
    }
}
