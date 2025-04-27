import SwiftUI
import Firebase
import FirebaseDatabase
import FirebaseStorage
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import AVFoundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Модель Story

struct Story: Identifiable {
    var id: String
    var name: String
    var image: String
    var videos: [StoryVideo]
}

struct StoryVideo: Identifiable {
    var id = UUID()
    var url: String
}

// MARK: - StoryIcon (с кастомной загрузкой)

struct StoryIcon: View {
    var story: Story
    let onPress: () -> Void

    // Подключаемся к нашему кэшу
    @ObservedObject var imageCache = ImageCache.shared

    @State private var uiImage: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Button(action: onPress) {
            VStack {
                ZStack {
                    if let image = uiImage {
                        // Есть готовая картинка
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if isLoading {
                        // Показываем загрузку
                        ProgressView()
                    } else {
                        // Какой-нибудь placeholder
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))

                Text(story.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 5)
        }
        .onAppear {
            loadIcon()
        }
    }

    private func loadIcon() {
        guard !story.image.isEmpty else { return }
        // Если уже есть в кэше – будем возвращены мгновенно
        isLoading = true
        imageCache.loadImage(from: story.image) { loaded in
            isLoading = false
            uiImage = loaded
        }
    }
}

// MARK: - ViewModel

class StoriesViewModel: ObservableObject {
    @Published var stories: [Story] = []

    @Published var adminPhones: [String] = []

    var isAdmin: Bool {
        if let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            return adminPhones.contains(savedPhone)
        }
#if canImport(FirebaseAuth)
        if let phone = Auth.auth().currentUser?.phoneNumber?.replacingOccurrences(of: "+", with: "") {
            return adminPhones.contains(phone)
        }
#endif
        return false
    }
    
    private let ref = Database.database(
        url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app"
    ).reference()
    
    /// Поменять порядок самих сторис
    func moveStory(fromIndex: Int, toIndex: Int) {
        ref.child("stories/stories").observeSingleEvent(of: .value) { snapshot in
            guard var arr = snapshot.value as? [[String: Any]],
                  fromIndex != toIndex,
                  fromIndex < arr.count, toIndex < arr.count else { return }
            let element = arr.remove(at: fromIndex)
            arr.insert(element, at: toIndex)
            snapshot.ref.setValue(arr) { error, _ in
                if error == nil {
                    DispatchQueue.main.async { self.fetchStories() }
                } else {
                    print("DEBUG: moveStory error \(error!)")
                }
            }
        }
    }
    
    /// Удалить сторис по индексу в массиве базы
    func deleteStory(at index: Int) {
        ref.child("stories/stories").observeSingleEvent(of: .value) { snapshot in
            guard var arr = snapshot.value as? [[String: Any]],
                  index < arr.count else { return }
            arr.remove(at: index)
            snapshot.ref.setValue(arr) { err, _ in
                if err == nil {
                    DispatchQueue.main.async { self.fetchStories() }
                } else {
                    print("DEBUG: deleteStory(at:) error \(err!)")
                }
            }
        }
    }
    
    func fetchStories() {
        ref.child("stories/stories").observeSingleEvent(of: .value) { snapshot in
            var loadedStories: [Story] = []

            if let storiesArray = snapshot.value as? [[String: Any]] {
                for (index, storyDict) in storiesArray.enumerated() {
                    let rawId = storyDict["id"] ?? ""
                    let id = "\(index)_\(rawId)"
                    let name = storyDict["name"] as? String ?? "Без имени"
                    let image = storyDict["image"] as? String ?? ""

                    var videos: [StoryVideo] = []
                    if let videosArray = storyDict["videos"] as? [[String: Any]] {
                        for videoData in videosArray {
                            if let url = videoData["url"] as? String {
                                videos.append(StoryVideo(url: url))
                            }
                        }
                    }

                    loadedStories.append(
                        Story(id: id, name: name, image: image, videos: videos)
                    )
                }
            }

            DispatchQueue.main.async {
                self.stories = loadedStories
                print("DEBUG: fetchStories loaded stories IDs: \(loadedStories.map { $0.id })")
                for s in loadedStories {
                    print("DEBUG: story \(s.id) videos: \(s.videos.map { $0.url })")
                }
            }

            // Загрузка списка номеров админов
            self.ref.child("stories/adminPhones").observeSingleEvent(of: .value) { snapshot in
                if let phonesDict = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        self.adminPhones = Array(phonesDict.keys)
                    }
                }
            }
        }
    }
    
    // MARK: - Admin helpers
    
    /// Удалить конкретный сторис
    func deleteStory(_ story: Story) {
        ref.child("stories/stories").observeSingleEvent(of: .value) { snapshot in
            guard var storiesArray = snapshot.value as? [[String: Any]] else { return }
            storiesArray.removeAll { ($0["id"] as? String) == story.id }
            snapshot.ref.setValue(storiesArray)
            
            DispatchQueue.main.async {
                self.stories.removeAll { $0.id == story.id }
            }
        }
    }
    
    /// Полностью удалить специалиста (в текущей структуре «Story» == «Specialist»)
    func deleteSpecialist(_ story: Story) {
        deleteStory(story)
    }
    
    /// Удалить все сторис полностью
    func deleteAllStories() {
        ref.child("stories/stories").setValue([]) // Очищаем массив в БД
        DispatchQueue.main.async {
            self.stories.removeAll() // Очищаем локальный массив
        }
    }
    
    /// Добавить нового специалиста со стартовым роликом
    func addSpecialist(name: String, image: String, videoUrl: String) {
        let newId = UUID().uuidString
        let newStoryDict: [String: Any] = [
            "id": newId,
            "name": name,
            "image": image,
            "videos": [["url": videoUrl]]
        ]
        
        ref.child("stories/stories").observeSingleEvent(of: .value) { snapshot in
            var storiesArray = snapshot.value as? [[String: Any]] ?? []
            storiesArray.append(newStoryDict)
            snapshot.ref.setValue(storiesArray)
            
            DispatchQueue.main.async {
                let newStory = Story(
                    id: newId,
                    name: name,
                    image: image,
                    videos: [StoryVideo(url: videoUrl)]
                )
                self.stories.append(newStory)
            }
        }
    }
    
    /// Ссылка на videos внутри конкретного сторис по индексу в базе
    private func videosRef(for story: Story) -> DatabaseReference {
        // story.id имеет вид "index_rawId"
        let indexPart = story.id.components(separatedBy: "_").first ?? "0"
        return ref.child("stories/stories").child(indexPart).child("videos")
    }
    
    /// Удалить конкретное видео из сторис
    func deleteVideo(from story: Story, video: StoryVideo) {
        let vRef = videosRef(for: story)
        vRef.observeSingleEvent(of: .value, with: { snapshot in
            guard var arr = snapshot.value as? [[String: Any]] else { return }
            arr.removeAll { ($0["url"] as? String) == video.url }
            vRef.setValue(arr, withCompletionBlock: { error, _ in
                if let error = error {
                    print("DEBUG: deleteVideo error \(error)")
                } else {
                    // Удаление файла из облака
                    if let url = URL(string: video.url) {
                        let key = url.path.dropFirst()
                        VKCloudUploader.shared.delete(fileName: String(key)) { result in
                            switch result {
                            case .success:
                                print("DEBUG: deleted remote file \(key)")
                            case .failure(let err):
                                print("DEBUG: cloud delete error: \(err)")
                            }
                            DispatchQueue.main.async {
                                self.fetchStories()
                            }
                        }
                    } else {
                        DispatchQueue.main.async { self.fetchStories() }
                    }
                }
            })
        })
    }

    /// Добавить видео в существующий сторис
    func addVideo(to story: Story, videoUrl: String) {
        let vRef = videosRef(for: story)
        vRef.observeSingleEvent(of: .value) { snap in
            var arr = snap.value as? [[String: Any]] ?? []
            arr.insert(["url": videoUrl], at: 0)
            vRef.setValue(arr) { err, _ in
                if err == nil {
                    DispatchQueue.main.async { self.fetchStories() }
                } else {
                    print("DEBUG: addVideo error \(err!)")
                }
            }
        }
    }

    /// Загрузить локальный видеофайл в VK Cloud и вернуть URL с прогрессом
    func uploadVideo(
        fileURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        VKCloudUploader.shared.upload(
            fileURL: fileURL,
            fileName: "videos/\(UUID().uuidString).mov",
            progress: progress,
            completion: { result in
                switch result {
                case .success(let url):
                    completion(.success(url.absoluteString))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }

    /// Загрузить локальный файл изображения в VK Cloud и вернуть URL
    /// Загрузить локальный файл изображения в VK Cloud и вернуть URL
    func uploadImage(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        VKCloudUploader.shared.upload(
            fileURL: fileURL,
            fileName: "images/\(UUID().uuidString).jpg",
            progress: { _ in /* здесь можно обновить прогресс, если нужно */ },
            completion: { result in
                switch result {
                case .success(let url):
                    completion(.success(url.absoluteString))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }

    /// Поменять порядок видео внутри сторис
    func moveVideo(in story: Story, fromIndex: Int, toIndex: Int) {
        let vRef = videosRef(for: story)
        vRef.observeSingleEvent(of: .value) { snap in
            guard var arr = snap.value as? [[String: Any]],
                  fromIndex != toIndex,
                  fromIndex < arr.count, toIndex < arr.count else { return }

            let elem = arr.remove(at: fromIndex)
            arr.insert(elem, at: toIndex)
            vRef.setValue(arr) { err, _ in
                if err == nil {
                    DispatchQueue.main.async { self.fetchStories() }
                } else {
                    print("DEBUG: moveVideo error \(err!)")
                }
            }
        }
    }
}

// MARK: - StoriesView

struct StoriesView: View {
    @ObservedObject var viewModel: StoriesViewModel
    @State private var selectedStory: Story? = nil
    @State private var showingAdminMenu = false

    // State для редактирования видео
    @State private var editingVideosFor: Story?
    @State private var showVideoEditor = false

    // Для scenePhase, чтобы обновлять сторис при возврате
    @Environment(\.scenePhase) var scenePhase

    // State для подтверждений удаления
    @State private var showDeleteAllConfirmation = false
    @State private var storyToDelete: Story?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if viewModel.stories.isEmpty {
                Text("Сторис недоступны. Пожалуйста, обновите экран.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                HStack {
                    ForEach(viewModel.stories) { story in
                        StoryIcon(story: story) {
                            selectedStory = story
                        }
                        .contextMenu {
                            if viewModel.isAdmin {
                                // Кнопка управления видео для конкретного сторис
                                Button {
                                    editingVideosFor = story
                                    showVideoEditor = true
                                } label: {
                                    Label("Управлять видео", systemImage: "film")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isAdmin {
                Button {
                    showingAdminMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.blue)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingAdminMenu) {
            AdminPanelView(viewModel: viewModel)
        }
        .sheet(isPresented: $showVideoEditor, onDismiss: { editingVideosFor = nil }) {
            if let story = editingVideosFor {
                StoryVideoAdminView(story: story, viewModel: viewModel)
                    .id(story.id)
            }
        }
        .onChange(of: showVideoEditor) { isPresented in
            if isPresented {
                viewModel.fetchStories()
            }
        }
        // Возможность обновления потягиванием вниз отключена
        // Если View появился на экране
        .onAppear {
            viewModel.fetchStories()
        }
        // Если пользователь вернулся в активное состояние (приложение / вкладка)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Повторяем fetchStories, чтобы удостовериться, что все загрузится
                viewModel.fetchStories()
            }
        }
        // При нажатии на иконку – полноэкранный режим
        .fullScreenCover(item: $selectedStory) { story in
            StoryPlayerView(story: story) {
                selectedStory = nil
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Подтвердите удаление"),
                message: Text("Вы уверены, что хотите удалить сторис \"\(storyToDelete?.name ?? "")\"?"),
                primaryButton: .destructive(Text("Удалить")) {
                    if let s = storyToDelete {
                        viewModel.deleteStory(s)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Подтвердите удаление всех сторис", isPresented: $showDeleteAllConfirmation) {
            Button("Удалить все", role: .destructive) {
                viewModel.deleteAllStories()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите удалить все сторис?")
        }
    }
}

// MARK: - StoryPlayerView

struct StoryPlayerView: View {
    var story: Story
    var onClose: () -> Void

    @State private var player = AVQueuePlayer()
    @State private var playerItems: [AVPlayerItem] = []
    @State private var currentVideoIndex: Int = 0
    @State private var currentVideoProgress: Double = 0.0
    @State private var timeObserverToken: Any?
    @State private var itemEndObserver: NSObjectProtocol?
    @State private var isPlayerReady = false

    var body: some View {
        ZStack {
            if isPlayerReady, player.currentItem != nil {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.play()
                    }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
                ProgressView()
            }

            VStack {
                // Прогресс-бар
                HStack(spacing: 4) {
                    ForEach(0..<story.videos.count, id: \.self) { index in
                        ProgressBarView(progress: progressFor(index: index))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                HStack {
                    HStack {
                        AsyncImage(url: URL(string: story.image)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        Text(story.name)
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    Spacer()
                    Button(action: { closePlayer() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            .zIndex(1)

            // Жесты на экране
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { playPreviousVideo() }
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { playNextVideo() }
            }
            .zIndex(0)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private func setupPlayer() {
        playerItems = story.videos.compactMap { video in
            guard let url = URL(string: video.url) else { return nil }
            let asset = AVAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 2
            return item
        }

        player.removeAllItems()
        isPlayerReady = false
        currentVideoIndex = 0
        currentVideoProgress = 0.0

        if let firstItem = playerItems.first {
            Task {
                do {
                    let _ : Bool = try await firstItem.asset.load(.isPlayable)
                    DispatchQueue.main.async {
                        player.replaceCurrentItem(with: firstItem)
                        for item in playerItems.dropFirst() {
                            player.insert(item, after: nil)
                        }
                        isPlayerReady = true
                        player.play()
                        addObservers()
                    }
                } catch {
                    print("Ошибка загрузки первого видео: \(error)")
                }
            }
        }
    }

    private func addObservers() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if let currentItem = player.currentItem,
               let index = playerItems.firstIndex(of: currentItem) {
                currentVideoIndex = index
                let duration = currentItem.duration.seconds
                currentVideoProgress = (duration > 0) ? (time.seconds / duration) : 0
            }
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main
        ) { notification in
            if let finishedItem = notification.object as? AVPlayerItem,
               finishedItem == player.currentItem {
                playNextVideo()
            }
        }
    }

    private func cleanupPlayer() {
        player.pause()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }
        player.removeAllItems()
        player.replaceCurrentItem(with: nil)
    }

    private func progressFor(index: Int) -> Double {
        if index < currentVideoIndex {
            return 1.0
        } else if index > currentVideoIndex {
            return 0.0
        } else {
            return currentVideoProgress
        }
    }

    private func playNextVideo() {
        if currentVideoIndex < playerItems.count - 1 {
            player.advanceToNextItem()
            currentVideoIndex += 1
            currentVideoProgress = 0.0
        } else {
            closePlayer()
        }
    }

    private func playPreviousVideo() {
        if currentVideoIndex > 0 {
            currentVideoIndex -= 1
            currentVideoProgress = 0.0
            player.pause()
            player.removeAllItems()
            for i in currentVideoIndex..<playerItems.count {
                player.insert(playerItems[i], after: nil)
            }
            player.currentItem?.seek(to: .zero, completionHandler: nil)
            player.play()
        }
    }

    private func closePlayer() {
        cleanupPlayer()
        onClose()
    }
}

struct ProgressBarView: View {
    var progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.3))
                Rectangle().fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(progress))
            }
            .cornerRadius(1)
        }
        .frame(height: 3)
    }
}


// MARK: - AdminPanelView

struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StoriesViewModel

    @State private var name = ""
    @State private var imageUrl: String?
    @State private var videoUrl: String?
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var isUploadingImage = false
    @State private var isUploadingVideo = false
    @State private var indexToDelete: Int? = nil
    @State private var showDeleteStoryAlert = false

    /// Обработка выбора фото специалиста
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let item = newItem else { return }
        isUploadingImage = true
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data?):
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".jpg")
                try? data.write(to: tmpURL)
                viewModel.uploadImage(fileURL: tmpURL) { res in
                    DispatchQueue.main.async {
                        isUploadingImage = false
                        if case .success(let url) = res {
                            imageUrl = url
                        }
                    }
                }
            default:
                DispatchQueue.main.async { isUploadingImage = false }
            }
        }
    }

    /// Обработка выбора видео специалиста
    private func handleVideoSelection(_ newItem: PhotosPickerItem?) {
        guard let item = newItem else { return }
        isUploadingVideo = true
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data?):
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mov")
                try? data.write(to: tmpURL)
                viewModel.uploadVideo(fileURL: tmpURL, progress: { _ in }, completion: { res in
                    DispatchQueue.main.async {
                        isUploadingVideo = false
                        if case .success(let url) = res {
                            videoUrl = url
                        }
                    }
                })
            default:
                DispatchQueue.main.async { isUploadingVideo = false }
            }
        }
    }

    /// Основное содержимое админ-панели
    private var adminContent: some View {
        List {
            Section(header: Text("Новый специалист")) {
                TextField("Имя", text: $name)
                PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {
                    Label("Выбрать фото специалиста", systemImage: "photo")
                }
                if isUploadingImage {
                    ProgressView("Загрузка фото...")
                }
                if let imageUrl = imageUrl {
                    Text("Фото загружено")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                PhotosPicker(selection: $selectedVideoItem, matching: .videos, photoLibrary: .shared()) {
                    Label("Выбрать видео специалиста", systemImage: "film")
                }
                if isUploadingVideo {
                    ProgressView("Загрузка видео...")
                }
                if let videoUrl = videoUrl {
                    Text("Видео загружено")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Button("Добавить") {
                    guard let img = imageUrl, let vid = videoUrl else { return }
                    viewModel.addSpecialist(name: name, image: img, videoUrl: vid)
                    dismiss()
                }
                .disabled(name.isEmpty || imageUrl == nil || videoUrl == nil)
            }
            Section(header: Text("Порядок сторис")) {
                ForEach(viewModel.stories) { story in
                    Text(story.name)
                }
                .onMove { indices, newOffset in
                    if let from = indices.first {
                        let to = newOffset > from ? newOffset - 1 : newOffset
                        viewModel.moveStory(fromIndex: from, toIndex: to)
                    }
                }
                .onDelete { indices in
                    if let idx = indices.first {
                        indexToDelete = idx
                        showDeleteStoryAlert = true
                    }
                }
            }
        }
    }

    /// Навигационный контейнер для упрощения модификаторов
    private var bodyContent: some View {
        NavigationView {
            adminContent
        }
    }

    var body: some View {
        bodyContent
            .onChange(of: selectedImageItem, perform: handleImageSelection)
            .onChange(of: selectedVideoItem, perform: handleVideoSelection)
            .navigationTitle("Админ‑панель")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Удалить сторис?", isPresented: $showDeleteStoryAlert, presenting: indexToDelete) { idx in
                Button("Удалить", role: .destructive) {
                    viewModel.deleteStory(at: idx)
                }
                Button("Отмена", role: .cancel) { }
            } message: { _ in
                if let idx = indexToDelete {
                    Text("Сторис \"\(viewModel.stories[idx].name)\" будет удалён безвозвратно.")
                } else {
                    Text("Это действие нельзя отменить.")
                }
            }
    }
}


// MARK: - StoryVideoAdminView

struct StoryVideoAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var environmentEditMode
    let story: Story
    @ObservedObject var viewModel: StoriesViewModel
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var uploadProgress: Double = 0
    @State private var editMode: EditMode = .inactive
    @State private var showVideoPicker = false

    /// Текущий список видео, обновляется из ViewModel
    private var videos: [StoryVideo] {
        viewModel.stories.first(where: { $0.id == story.id })?.videos ?? []
    }

    /// Основное содержимое экрана управления видео
    private var videoContent: some View {
        VStack {
            if uploadProgress > 0 {
                VStack {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                        .padding(.horizontal)
                    Text("Загрузка: \(Int(uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 4)
                )
                .padding(.horizontal)
            }
            List {
                Section(header: Text("Видео сторис \"\(story.name)\"")) {
                    ForEach(videos) { video in
                        // Видео-превью в карточке
                        if let url = URL(string: video.url) {
                            VideoThumbnailView(url: url)
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .padding(.vertical, 8)
                        }
                    }
                    .onMove { indices, newOffset in
                        if let from = indices.first {
                            let to = newOffset > from ? newOffset - 1 : newOffset
                            viewModel.moveVideo(in: story, fromIndex: from, toIndex: to)
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            let video = videos[index]
                            viewModel.deleteVideo(from: story, video: video)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }

    var body: some View {
        NavigationView {
            videoContent
                .navigationTitle("Управление видео")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Закрыть") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        EditButton()
                        Button {
                            showVideoPicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .photosPicker(
                            isPresented: $showVideoPicker,
                            selection: $selectedVideoItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        )
                    }
                }
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            viewModel.fetchStories()
        }
        .onChange(of: selectedVideoItem) { newItem in
            guard let item = newItem else { return }
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data?):
                    let tmpURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".mov")
                    try? data.write(to: tmpURL)
                    uploadProgress = 0.0
                    viewModel.uploadVideo(
                        fileURL: tmpURL,
                        progress: { p in
                            DispatchQueue.main.async {
                                uploadProgress = max(0.01, p)
                            }
                        },
                        completion: { res in
                            DispatchQueue.main.async {
                                uploadProgress = 1.0
                                switch res {
                                case .success(let urlString):
                                    viewModel.addVideo(to: story, videoUrl: urlString)
                                    viewModel.fetchStories()
                                case .failure(let error):
                                    print("Upload error: \(error)")
                                }
                                // Сброс selection чтобы можно было выбрать заново
                                selectedVideoItem = nil
                                showVideoPicker = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        uploadProgress = 0.0
                                    }
                                }
                            }
                        }
                    )
                default:
                    break
                }
            }
        }
    }
}

// MARK: - VideoThumbnailView

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .frame(height: 100)
        .clipped()
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 200, height: 200)
                if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                    let uiImage = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        image = uiImage
                    }
                }
            }
        }
    }
}


struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesView(viewModel: StoriesViewModel())
    }
}
