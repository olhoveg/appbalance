import SwiftUI
import Firebase
import FirebaseDatabase
import AVKit

// MARK: - Модели данных

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

// MARK: - StoryIcon

struct StoryIcon: View {
    var imageUrl: String
    var name: String
    var onPress: () -> Void

    var body: some View {
        Button(action: onPress) {
            VStack {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 5)
        }
    }
}

// MARK: - StoriesViewModel

class StoriesViewModel: ObservableObject {
    @Published var stories: [Story] = []
    
    // URL базы данных
    private let ref = Database.database(url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app").reference()
    
    func fetchStories() {
        print("StoriesViewModel: Начинаем загрузку сторис.")
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
                    
                    let story = Story(id: id, name: name, image: image, videos: videos)
                    loadedStories.append(story)
                }
            } else {
                print("StoriesViewModel: Не удалось преобразовать snapshot.value в массив сторис.")
            }
            
            DispatchQueue.main.async {
                self.stories = loadedStories
                if loadedStories.isEmpty {
                    print("StoriesViewModel: Загрузка сторис завершена, но сторис не найдены.")
                } else {
                    print("StoriesViewModel: Загрузка сторис завершена успешно, загружено сторис: \(loadedStories.count)")
                }
            }
        }
    }
}


// MARK: - StoriesView

struct StoriesView: View {
    @ObservedObject var viewModel: StoriesViewModel
    @State private var selectedStory: Story? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(viewModel.stories) { story in
                    StoryIcon(imageUrl: story.image, name: story.name) {
                        selectedStory = story
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            viewModel.fetchStories()
        }
        .onAppear {
            viewModel.fetchStories()
        }
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

    @State private var currentVideoIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var currentVideoProgress: Double = 0.0
    @State private var timeObserverToken: Any?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear { player.play() }
                    .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                        playNextVideo()
                    }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
                Text("Нет видео")
                    .foregroundColor(.white)
            }
            VStack {
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
                                image.resizable().aspectRatio(contentMode: .fill)
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
                    .zIndex(2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            .zIndex(1)
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { playPreviousVideo() }
                Color.clear.contentShape(Rectangle()).onTapGesture { playNextVideo() }
            }
            .zIndex(0)
        }
        .onAppear { startCurrentVideo() }
        .onDisappear { closePlayer() }
    }
    
    func progressFor(index: Int) -> Double {
        if index < currentVideoIndex {
            return 1.0
        } else if index > currentVideoIndex {
            return 0.0
        } else {
            return currentVideoProgress
        }
    }
    
    func startCurrentVideo() {
        guard currentVideoIndex < story.videos.count else { closePlayer(); return }
        if let player = player {
            player.pause()
            if let token = timeObserverToken {
                player.removeTimeObserver(token)
                timeObserverToken = nil
            }
        }
        currentVideoProgress = 0.0
        let videoUrlString = story.videos[currentVideoIndex].url
        if let url = URL(string: videoUrlString) {
            let newPlayer = AVPlayer(url: url)
            newPlayer.play()
            player = newPlayer
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                if let duration = newPlayer.currentItem?.duration.seconds, duration > 0 {
                    currentVideoProgress = time.seconds / duration
                }
            }
        }
    }
    
    func playNextVideo() {
        currentVideoIndex += 1
        if currentVideoIndex < story.videos.count {
            startCurrentVideo()
        } else {
            closePlayer()
        }
    }
    
    func playPreviousVideo() {
        if currentVideoIndex > 0 {
            currentVideoIndex -= 1
            startCurrentVideo()
        }
    }
    
    func closePlayer() {
        player?.pause()
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
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
