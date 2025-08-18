import SwiftUI
import AVKit

struct VideoLessonDetailView: View {
    let lesson: VideoLesson
    let viewModel: VideoLessonViewModel
    let userPhone: String
    let onPurchase: (VideoLesson) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPlayer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                                            .font(.system(size: 40))
                                            .foregroundColor(.secondary)
                                    )
                            }
                            .frame(height: 200)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "video")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // Кнопка воспроизведения
                        Button(action: {
                            if lesson.isPurchased {
                                showingVideoPlayer = true
                            }
                        }) {
                            Image(systemName: lesson.isPurchased ? "play.circle.fill" : "lock.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(lesson.isPurchased ? .white : .orange)
                                .background(Circle().fill(Color.black.opacity(0.3)))
                        }
                        .disabled(!lesson.isPurchased)
                    }
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Название
                        Text(lesson.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Цена и скидка
                        VStack(alignment: .leading, spacing: 8) {
                            if lesson.hasActiveDiscount {
                                HStack(spacing: 8) {
                                    Text(viewModel.formatPrice(lesson.currentPrice))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    
                                    Text("-\(lesson.discountPercentage ?? 0)%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Text(viewModel.formatPrice(lesson.originalPrice))
                                    .font(.subheadline)
                                    .strikethrough()
                                    .foregroundColor(.secondary)
                                
                                // Таймер обратного отсчета
                                if let discount = lesson.discount {
                                    DiscountTimerView(endDate: discount.endDate)
                                }
                            } else {
                                Text(viewModel.formatPrice(lesson.currentPrice))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        // Информация о видео
                        VStack(alignment: .leading, spacing: 12) {
                            if let instructor = lesson.instructor {
                                InfoRow(icon: "person.circle", title: "Инструктор", value: instructor)
                            }
                            
                            if let category = lesson.category {
                                InfoRow(icon: "tag", title: "Категория", value: category)
                            }
                            
                            if let duration = lesson.duration {
                                InfoRow(icon: "clock", title: "Длительность", value: viewModel.formatDuration(duration))
                            }
                            
                            if lesson.isPurchased, let purchaseDate = lesson.purchaseDate {
                                InfoRow(icon: "checkmark.circle", title: "Куплено", value: formatDate(purchaseDate))
                            }
                        }
                        
                        // Полное описание
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Описание")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(lesson.description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                        
                        // Кнопка покупки/просмотра
                        if !lesson.isPurchased {
                            Button(action: {
                                onPurchase(lesson)
                                dismiss()
                            }) {
                                HStack {
                                    if viewModel.isProcessingPayment(for: lesson.id) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "cart")
                                    }
                                    
                                    Text(viewModel.isProcessingPayment(for: lesson.id) ? "Обработка..." : "Купить за \(viewModel.formatPrice(lesson.currentPrice))")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isProcessingPayment(for: lesson.id))
                        } else {
                            Button(action: {
                                showingVideoPlayer = true
                            }) {
                                HStack {
                                    Image(systemName: "play")
                                    Text("Смотреть видео")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Детали урока")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            VideoPlayerView(videoUrl: lesson.videoUrl, title: lesson.title)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Вспомогательный компонент для отображения информации
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VideoLessonDetailView(
        lesson: VideoLesson(
            id: "preview_1",
            title: "Основы массажа спины",
            description: "Подробный видео урок по технике массажа спины для начинающих. В этом уроке вы изучите основные приемы и техники массажа, которые помогут снять напряжение и улучшить самочувствие. Урок включает в себя практические упражнения и рекомендации по правильному выполнению массажных движений.",
            price: 1500,
            videoUrl: "https://example.com/video.mp4",
            thumbnailUrl: nil,
            duration: 1800,
            category: "Массаж",
            instructor: "Анна Петрова",
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        viewModel: VideoLessonViewModel(),
        userPhone: "+79001234567",
        onPurchase: { _ in }
    )
}
