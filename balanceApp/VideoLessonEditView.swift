import SwiftUI
import PhotosUI
import AVKit
import AppMetricaCore

struct VideoLessonEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VideoLessonViewModel
    let lesson: VideoLesson
    
    @State private var title: String
    @State private var description: String
    @State private var price: String
    @State private var category: String
    @State private var instructor: String
    @State private var duration: String
    @State private var isActive: Bool
    
    // Скидка
    @State private var hasDiscount: Bool = false
    @State private var discountPercentage: String = ""
    @State private var discountStartDate = Date()
    @State private var discountEndDate = Date().addingTimeInterval(24 * 60 * 60) // +1 день
    @State private var discountIsActive: Bool = true
    
    // Загрузка файлов
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var selectedThumbnailItem: PhotosPickerItem? = nil
    @State private var videoUrl: String?
    @State private var thumbnailUrl: String?
    
    @State private var isUploadingVideo = false
    @State private var isUploadingThumbnail = false
    @State private var uploadProgress: Double = 0
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    init(lesson: VideoLesson, viewModel: VideoLessonViewModel) {
        self.lesson = lesson
        self.viewModel = viewModel
        
        // Инициализация состояния
        _title = State(initialValue: lesson.title)
        _description = State(initialValue: lesson.description)
        _price = State(initialValue: String(lesson.price))
        _category = State(initialValue: lesson.category ?? "")
        _instructor = State(initialValue: lesson.instructor ?? "")
        _duration = State(initialValue: lesson.duration.map(String.init) ?? "")
        _isActive = State(initialValue: lesson.isActive)
        
        // Инициализация скидки
        if let discount = lesson.discount {
            _hasDiscount = State(initialValue: true)
            _discountPercentage = State(initialValue: String(discount.percentage))
            _discountStartDate = State(initialValue: discount.startDate)
            _discountEndDate = State(initialValue: discount.endDate)
            _discountIsActive = State(initialValue: discount.isActive)
        }
        
        _videoUrl = State(initialValue: lesson.videoUrl)
        _thumbnailUrl = State(initialValue: lesson.thumbnailUrl)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Основная информация
                Section("Основная информация") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Цена (руб.)", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Категория", text: $category)
                    TextField("Инструктор", text: $instructor)
                    TextField("Длительность (сек.)", text: $duration)
                        .keyboardType(.numberPad)
                    Toggle("Активен", isOn: $isActive)
                }
                
                // Скидка
                Section("Скидка") {
                    Toggle("Добавить скидку", isOn: $hasDiscount)
                    
                    if hasDiscount {
                        TextField("Процент скидки", text: $discountPercentage)
                            .keyboardType(.numberPad)
                        
                        DatePicker("Начало акции", selection: $discountStartDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Конец акции", selection: $discountEndDate, displayedComponents: [.date, .hourAndMinute])
                        
                        Toggle("Активна", isOn: $discountIsActive)
                        
                        if let percentage = Int(discountPercentage), percentage > 0 {
                            let originalPrice = Int(price) ?? 0
                            let discountedPrice = originalPrice * (100 - percentage) / 100
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Предварительный просмотр:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("\(originalPrice) ₽")
                                        .strikethrough()
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(discountedPrice) ₽")
                                        .foregroundColor(.red)
                                        .fontWeight(.bold)
                                    
                                    Text("-\(percentage)%")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Файлы
                Section("Файлы") {
                    if let videoUrl = videoUrl {
                        HStack {
                            Image(systemName: "video")
                            Text("Видео загружено")
                            Spacer()
                            Button("Изменить") {
                                selectedVideoItem = nil
                                self.videoUrl = nil
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                            HStack {
                                Image(systemName: "video.badge.plus")
                                Text("Выбрать видео")
                            }
                        }
                    }
                    
                    if let thumbnailUrl = thumbnailUrl {
                        HStack {
                            Image(systemName: "photo")
                            Text("Превью загружено")
                            Spacer()
                            Button("Изменить") {
                                selectedThumbnailItem = nil
                                self.thumbnailUrl = nil
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        PhotosPicker(selection: $selectedThumbnailItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Выбрать превью")
                            }
                        }
                    }
                }
                
                // Прогресс загрузки
                if isUploadingVideo || isUploadingThumbnail {
                    Section("Загрузка") {
                        VStack {
                            ProgressView(value: uploadProgress)
                            Text("Загрузка файлов... \(Int(uploadProgress * 100))%")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Редактировать урок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveLesson()
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Результат", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedVideoItem) { item in
                handleVideoSelection(item)
            }
            .onChange(of: selectedThumbnailItem) { item in
                handleThumbnailSelection(item)
            }
        }
    }
    
    private var canSave: Bool {
        !title.isEmpty && !description.isEmpty && !price.isEmpty && !category.isEmpty && !instructor.isEmpty
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isUploadingVideo = true
        uploadProgress = 0
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        uploadVideo(data: data)
                    } else {
                        alertMessage = "Не удалось загрузить данные видео"
                        showingAlert = true
                        isUploadingVideo = false
                    }
                case .failure(let error):
                    alertMessage = "Ошибка загрузки видео: \(error.localizedDescription)"
                    showingAlert = true
                    isUploadingVideo = false
                }
            }
        }
    }
    
    private func handleThumbnailSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isUploadingThumbnail = true
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        uploadThumbnail(data: data)
                    } else {
                        alertMessage = "Не удалось загрузить данные превью"
                        showingAlert = true
                        isUploadingThumbnail = false
                    }
                case .failure(let error):
                    alertMessage = "Ошибка загрузки превью: \(error.localizedDescription)"
                    showingAlert = true
                    isUploadingThumbnail = false
                }
            }
        }
    }
    
    private func uploadVideo(data: Data) {
        let fileName = "videoLessons/videos/\(lesson.id)_video_\(Date().timeIntervalSince1970).mp4"
        
        // Создаем временный файл
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video_\(Date().timeIntervalSince1970).mp4")
        
        do {
            try data.write(to: tempURL)
            
            VKCloudUploader.shared.upload(
                fileURL: tempURL,
                fileName: fileName,
                progress: { progress in
                    DispatchQueue.main.async {
                        self.uploadProgress = progress * 0.5
                    }
                },
                completion: { result in
                    DispatchQueue.main.async {
                        // Удаляем временный файл
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        switch result {
                        case .success(let url):
                            self.videoUrl = url.absoluteString
                            self.uploadProgress += 0.5
                        case .failure(let error):
                            self.alertMessage = "Ошибка загрузки видео: \(error.localizedDescription)"
                            self.showingAlert = true
                        }
                        self.isUploadingVideo = false
                    }
                }
            )
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Ошибка создания временного файла: \(error.localizedDescription)"
                self.showingAlert = true
                self.isUploadingVideo = false
            }
        }
    }
    
    private func uploadThumbnail(data: Data) {
        let fileName = "videoLessons/thumbnails/\(lesson.id)_thumb_\(Date().timeIntervalSince1970).jpg"
        
        // Создаем временный файл
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_thumb_\(Date().timeIntervalSince1970).jpg")
        
        do {
            try data.write(to: tempURL)
            
            VKCloudUploader.shared.upload(
                fileURL: tempURL,
                fileName: fileName,
                progress: { progress in
                    DispatchQueue.main.async {
                        self.uploadProgress = 0.5 + (progress * 0.5)
                    }
                },
                completion: { result in
                    DispatchQueue.main.async {
                        // Удаляем временный файл
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        switch result {
                        case .success(let url):
                            self.thumbnailUrl = url.absoluteString
                            self.uploadProgress += 0.5
                        case .failure(let error):
                            self.alertMessage = "Ошибка загрузки превью: \(error.localizedDescription)"
                            self.showingAlert = true
                        }
                        self.isUploadingThumbnail = false
                    }
                }
            )
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Ошибка создания временного файла: \(error.localizedDescription)"
                self.showingAlert = true
                self.isUploadingThumbnail = false
            }
        }
    }
    
    private func saveLesson() {
        guard canSave else { return }
        
        isSaving = true
        
        // Создаем скидку если нужно
        var discount: Discount?
        if hasDiscount, let percentage = Int(discountPercentage), percentage > 0 {
            discount = Discount(
                percentage: percentage,
                startDate: discountStartDate,
                endDate: discountEndDate,
                isActive: discountIsActive
            )
        }
        
        // Создаем обновленный урок
        let updatedLesson = VideoLesson(
            id: lesson.id,
            title: title,
            description: description,
            price: Int(price) ?? 0,
            videoUrl: videoUrl ?? lesson.videoUrl,
            thumbnailUrl: thumbnailUrl ?? lesson.thumbnailUrl,
            duration: Int(duration),
            category: category,
            instructor: instructor,
            isActive: isActive,
            createdAt: lesson.createdAt,
            updatedAt: Date()
        )
        
        // Добавляем скидку
        var lessonWithDiscount = updatedLesson
        lessonWithDiscount.discount = discount
        
        // Сохраняем в Firebase
        viewModel.updateVideoLesson(lessonWithDiscount) { success in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    alertMessage = "Урок успешно обновлен!"
                    showingAlert = true
                    dismiss()
                } else {
                    alertMessage = "Ошибка обновления урока"
                    showingAlert = true
                }
            }
        }
    }
}

struct VideoLessonEditView_Previews: PreviewProvider {
    static var previews: some View {
        VideoLessonEditView(
            lesson: VideoLesson(
                id: "preview_1",
                title: "Тестовый урок",
                description: "Описание тестового урока",
                price: 1500,
                videoUrl: "https://example.com/video.mp4",
                thumbnailUrl: nil,
                duration: 1800,
                category: "Тест",
                instructor: "Тестовый инструктор",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            viewModel: VideoLessonViewModel()
        )
    }
}
