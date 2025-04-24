import SwiftUI
import Firebase
import FirebaseDatabase
import AVKit

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

    private let ref = Database.database(
      url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app"
    ).reference()

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
            }
        }
    }
}

// MARK: - StoriesView

struct StoriesView: View {
    @ObservedObject var viewModel: StoriesViewModel
    @State private var selectedStory: Story? = nil

    // Для scenePhase, чтобы обновлять сторис при возврате
    @Environment(\.scenePhase) var scenePhase

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
                    }
                }
                .padding(.horizontal)
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


struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesView(viewModel: StoriesViewModel())
    }
}
