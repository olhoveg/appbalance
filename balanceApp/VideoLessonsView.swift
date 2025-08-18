import SwiftUI
import AppMetricaCore

struct VideoLessonsView: View {
    @StateObject private var viewModel = VideoLessonViewModel()
    @AppStorage("userPhone") var userPhone: String = ""
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingPurchaseAlert = false
    @State private var selectedVideoLesson: VideoLesson?
    @State private var showingAdminPanel = false
    
    private var filteredVideoLessons: [VideoLesson] {
        var filtered = viewModel.videoLessons
        
        if !searchText.isEmpty {
            filtered = filtered.filter { lesson in
                lesson.title.localizedCaseInsensitiveContains(searchText) ||
                lesson.description.localizedCaseInsensitiveContains(searchText) ||
                (lesson.instructor?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if let category = selectedCategory {
            filtered = filtered.filter { lesson in
                lesson.category == category
            }
        }
        
        return filtered
    }
    
    private var categories: [String] {
        Array(Set(viewModel.videoLessons.compactMap { $0.category })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Кастомный NavigationBar
                CustomVideoLessonsNavigationBar()
                
                VStack(spacing: 16) {
                    // Поиск
                    SearchBar(text: $searchText)
                    
                    // Фильтр по категориям
                    if !categories.isEmpty {
                        CategoryFilterView(
                            categories: categories,
                            selectedCategory: $selectedCategory
                        )
                    }
                    
                    // Счетчик результатов
                    HStack {
                        Text("Найдено: \(filteredVideoLessons.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                
                // Список видео уроков
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Загрузка видео уроков...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if filteredVideoLessons.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Видео уроки не найдены")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Попробуйте изменить поисковый запрос или фильтры")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ], spacing: 20) {
                            ForEach(filteredVideoLessons) { lesson in
                                VideoLessonCardView(
                                    lesson: lesson,
                                    viewModel: viewModel,
                                    userPhone: userPhone,
                                    onPurchase: { selectedLesson in
                                        print("📱 Выбран урок для покупки: \(selectedLesson.title)")
                                        selectedVideoLesson = selectedLesson
                                        showingPurchaseAlert = true
                                    }
                                )
                                .id(lesson.id) // Уникальный ID для каждого элемента
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.isAdmin {
                    Button {
                        showingAdminPanel = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if !userPhone.isEmpty {
                // Загружаем данные из Firebase
                viewModel.fetchVideoLessons(phone: userPhone)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Обновляем данные при возвращении в приложение
            if !userPhone.isEmpty {
                viewModel.refreshVideoLessons(phone: userPhone)
            }
        }
        .refreshable {
            if !userPhone.isEmpty {
                viewModel.refreshVideoLessons(phone: userPhone)
            }
        }
        .alert("Подтверждение покупки", isPresented: $showingPurchaseAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Купить") {
                if let lesson = selectedVideoLesson {
                    purchaseVideoLesson(lesson)
                }
            }
        } message: {
            if let lesson = selectedVideoLesson {
                Text("Вы уверены, что хотите купить видео урок \"\(lesson.title)\" за \(viewModel.formatPrice(lesson.currentPrice))?")
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Успешная покупка!", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.showSuccessAlert = false
            }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Ошибка платежа", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
                viewModel.showErrorAlert = false
            }
        } message: {
            Text(viewModel.errorAlertMessage)
        }
        .sheet(isPresented: $showingAdminPanel) {
            VideoLessonListAdminView(viewModel: viewModel)
        }
    }
    
    private func purchaseVideoLesson(_ lesson: VideoLesson) {
        viewModel.purchaseVideoLesson(videoId: lesson.id, phone: userPhone) { success in
            if success {
                AppMetrica.reportEvent(name: "Пользователь купил видео урок", parameters: [
                    "video_id": lesson.id,
                    "video_title": lesson.title,
                    "price": lesson.currentPrice
                ])
                // Алерт об успешной покупке показывается автоматически в ViewModel
            }
        }
    }
}

// MARK: - Кастомный NavigationBar для видео уроков
struct CustomVideoLessonsNavigationBar: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                AppMetrica.reportEvent(name: "Пользователь нажал на иконку профиля в видео уроках")
            })
            .zIndex(1)
            
            Spacer()
            
            Text("Видео уроки")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    if let url = URL(string: "https://wa.me/79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "message.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку чата в видео уроках")
                })
                
                Button(action: {
                    if let url = URL(string: "tel://+79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку телефона в видео уроках")
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Поисковая строка
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Поиск видео уроков...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Фильтр по категориям
struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: {
                    selectedCategory = nil
                }) {
                    Text("Все")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == nil ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selectedCategory == nil ? .white : .primary)
                        .cornerRadius(20)
                }
                
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct VideoLessonsView_Previews: PreviewProvider {
    static var previews: some View {
        VideoLessonsView()
    }
}
