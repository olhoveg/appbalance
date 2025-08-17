import SwiftUI
import AppMetricaCore

struct PurchasedVideoLessonsView: View {
    @StateObject private var viewModel = VideoLessonViewModel()
    @AppStorage("userPhone") var userPhone: String = ""
    @State private var showingVideoPlayer = false
    @State private var selectedVideoUrl = ""
    @State private var selectedVideoTitle = ""
    
    private var purchasedVideoLessons: [VideoLesson] {
        viewModel.videoLessons.filter { $0.isPurchased }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("Мои видео уроки")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(purchasedVideoLessons.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.isLoading {
                Spacer()
                ProgressView("Загрузка...")
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if purchasedVideoLessons.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("У вас пока нет купленных видео уроков")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Перейдите в раздел 'Видео уроки' для покупки")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(purchasedVideoLessons) { lesson in
                            PurchasedVideoLessonRowView(
                                lesson: lesson,
                                viewModel: viewModel,
                                onPlay: { videoUrl, title in
                                    selectedVideoUrl = videoUrl
                                    selectedVideoTitle = title
                                    showingVideoPlayer = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if !userPhone.isEmpty {
                // Загружаем данные из Firebase
                viewModel.fetchVideoLessons(phone: userPhone)
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            VideoPlayerView(videoUrl: selectedVideoUrl, title: selectedVideoTitle)
        }
    }
}

// MARK: - Строка купленного видео урока
struct PurchasedVideoLessonRowView: View {
    let lesson: VideoLesson
    let viewModel: VideoLessonViewModel
    let onPlay: (String, String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Превью видео
            ZStack {
                if let thumbnailUrl = lesson.thumbnailUrl, !thumbnailUrl.isEmpty {
                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "video")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 80, height: 60)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 60)
                        .overlay(
                            Image(systemName: "video")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        )
                }
                
                // Кнопка воспроизведения
                Button(action: {
                    onPlay(lesson.videoUrl, lesson.title)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
            }
            .cornerRadius(8)
            
            // Информация о видео
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let instructor = lesson.instructor {
                    Text("Инструктор: \(instructor)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let duration = lesson.duration {
                    Text("Длительность: \(viewModel.formatDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let purchaseDate = lesson.purchaseDate {
                    Text("Куплено: \(formatDate(purchaseDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Кнопка воспроизведения
            Button(action: {
                onPlay(lesson.videoUrl, lesson.title)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct PurchasedVideoLessonsView_Previews: PreviewProvider {
    static var previews: some View {
        PurchasedVideoLessonsView()
    }
}
