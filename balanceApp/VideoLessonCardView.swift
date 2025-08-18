import SwiftUI
import AVKit

struct VideoLessonCardView: View {
    let lesson: VideoLesson
    let viewModel: VideoLessonViewModel
    let userPhone: String
    let onPurchase: (VideoLesson) -> Void
    
    @State private var showingVideoPlayer = false
    @State private var showingPurchaseAlert = false
    @State private var showingDescriptionDetail = false
    
    // Проверяем, является ли пользователь админом
    private var isAdmin: Bool {
        viewModel.isAdmin
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Видео превью
            ZStack {
                AsyncImage(url: URL(string: lesson.thumbnailUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 120)
                .clipped()
                
                // Кнопка воспроизведения
                Button(action: {
                    print("🎬 Нажата кнопка воспроизведения для урока: \(lesson.title)")
                    print("   ID: \(lesson.id)")
                    print("   isPurchased: \(lesson.isPurchased)")
                    
                    if lesson.isPurchased {
                        showingVideoPlayer = true
                    } else {
                        onPurchase(lesson)
                    }
                }) {
                    Image(systemName: lesson.isPurchased ? "play.circle.fill" : "lock.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(lesson.isPurchased ? .white : .orange)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
                
                // Индикатор длительности
                if let duration = lesson.duration {
                    VStack {
                        HStack {
                            Spacer()
                            Text(viewModel.formatDuration(duration))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Индикатор покупки
                if lesson.isPurchased {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Spacer()
                            
                            // Кнопка принудительного обновления (только для админов)
                            if isAdmin {
                                Button(action: {
                                    viewModel.forceUpdateLessonPurchaseStatus(lessonId: lesson.id, phone: userPhone)
                                }) {
                                    Image(systemName: "arrow.clockwise.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Индикатор скидки
                if lesson.hasActiveDiscount {
                    VStack {
                        HStack {
                            Spacer()
                            Text("-\(lesson.discountPercentage ?? 0)%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .cornerRadius(12)
            
            // Информация о видео
            VStack(alignment: .leading, spacing: 8) {
                // Название
                Text(lesson.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // Описание
                Button(action: {
                    showingDescriptionDetail = true
                }) {
                    HStack {
                        Text(lesson.description)
                            .font(.caption)
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Инструктор
                if let instructor = lesson.instructor {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(instructor)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Категория
                if let category = lesson.category {
                    HStack {
                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Цена и кнопка
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if lesson.hasActiveDiscount {
                            // Показываем скидку
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(viewModel.formatPrice(lesson.currentPrice))
                                        .font(.headline)
                                        .foregroundColor(.red)
                                        .fontWeight(.bold)
                                    
                                    Text("-\(lesson.discountPercentage ?? 0)%")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
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
                            // Обычная цена
                            Text(viewModel.formatPrice(lesson.currentPrice))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        print("🔘 Нажата кнопка для урока: \(lesson.title)")
                        print("   ID: \(lesson.id)")
                        print("   Куплен: \(lesson.isPurchased)")
                        print("   Обрабатывается: \(viewModel.isProcessingPayment(for: lesson.id))")
                        print("   Пользователь: \(userPhone)")
                        print("   Кнопка показывает: \(lesson.isPurchased ? "Смотреть" : "Купить")")
                        
                        if lesson.isPurchased {
                            print("🎬 Открываем видео для купленного урока")
                            showingVideoPlayer = true
                        } else {
                            print("🛒 Начинаем покупку урока")
                            onPurchase(lesson)
                        }
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isProcessingPayment(for: lesson.id) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: lesson.isPurchased ? "play" : "cart")
                                    .font(.caption)
                            }
                            
                            Text(lesson.isPurchased ? "Смотреть" : "Купить")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(lesson.isPurchased ? Color.green : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isProcessingPayment(for: lesson.id))
                    .contentShape(Rectangle()) // Улучшаем hit testing
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle()) // Улучшаем hit testing для всей карточки
        .contextMenu {
            if isAdmin {
                Button(lesson.isActive ? "Деактивировать" : "Активировать") {
                    viewModel.toggleVideoLessonActive(lesson.id) { _ in }
                }
                Button("Отладка покупки") {
                    viewModel.debugLessonPurchaseStatus(lessonId: lesson.id, phone: userPhone)
                }
                Button("Принудительное обновление") {
                    viewModel.forceUpdateLessonPurchaseStatus(lessonId: lesson.id, phone: userPhone)
                }
                Button("Удалить", role: .destructive) {
                    viewModel.deleteVideoLesson(lesson.id) { _ in }
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            VideoPlayerView(videoUrl: lesson.videoUrl, title: lesson.title)
        }
        .sheet(isPresented: $showingDescriptionDetail) {
            VideoLessonDetailView(
                lesson: lesson, 
                viewModel: viewModel,
                userPhone: userPhone,
                onPurchase: onPurchase
            )
        }
    }
}

// MARK: - Видео плеер
struct VideoPlayerView: View {
    let videoUrl: String
    let title: String
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationView {
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    VStack {
                        ProgressView("Загрузка видео...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Ошибка загрузки видео")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let url = URL(string: videoUrl) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Скелетон для загрузки
struct SkeletonVideoLessonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 120)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .cornerRadius(4)
                
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 20)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 30)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct VideoLessonCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            VideoLessonCardView(
                lesson: VideoLesson(
                    id: "preview_1",
                    title: "Основы массажа спины",
                    description: "Подробный видео урок по технике массажа спины для начинающих",
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
            
            SkeletonVideoLessonCardView()
        }
        .padding()
    }
}
