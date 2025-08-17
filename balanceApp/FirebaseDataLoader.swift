import SwiftUI
import FirebaseDatabase

// MARK: - Интерфейс для загрузки тестовых данных в Firebase

struct FirebaseDataLoader: View {
    @StateObject private var viewModel = VideoLessonViewModel()
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var loadedLessonsCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Загрузка тестовых данных в Firebase")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Этот интерфейс загружает тестовые видео уроки в Firebase для демонстрации системы.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Загруженные уроки будут содержать:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• 8 различных видео уроков")
                        Text("• Разные категории (Массаж, Уход за лицом, и др.)")
                        Text("• Разных инструкторов")
                        Text("• Разные цены и длительности")
                        Text("• Тестовые скидки (20% и 15%)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка данных в Firebase...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Загружено: \(loadedLessonsCount)/8")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding()
                } else {
                    Button(action: loadTestData) {
                        HStack {
                            Image(systemName: "cloud.upload")
                            Text("Загрузить тестовые данные")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                
                Button(action: addTestAdmin) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Добавить тестового админа")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Button(action: clearAllData) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Очистить все данные")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Spacer()
                
                VStack(spacing: 10) {
                    Text("После загрузки данных:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("1. Перейдите на вкладку 'Видео уроки'")
                        Text("2. Увидите загруженные уроки")
                        Text("3. Попробуйте поиск и фильтрацию")
                        Text("4. Протестируйте покупки")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Firebase Data Loader")
            .alert("Результат", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadTestData() {
        isLoading = true
        loadedLessonsCount = 0
        
        // Создаем тестовые данные
        let testLessons = [
            VideoLesson(
                id: "lesson_1",
                title: "Основы массажа спины",
                description: "Подробный видео урок по технике массажа спины для начинающих. Изучите основные приемы и правильную последовательность движений.",
                price: 1500,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=1",
                duration: 1800,
                category: "Массаж",
                instructor: "Анна Петрова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
                discount: Discount(
                    percentage: 20,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // +7 дней
                    isActive: true
                )
            ),
            VideoLesson(
                id: "lesson_2",
                title: "Техника глубокого массажа",
                description: "Продвинутые техники глубокого массажа для опытных специалистов. Работа с глубокими мышцами и фасциями.",
                price: 2500,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=2",
                duration: 2400,
                category: "Массаж",
                instructor: "Михаил Соколов",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_3",
                title: "СПА процедуры для лица",
                description: "Комплексный уход за лицом с использованием профессиональных средств и техник.",
                price: 1200,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=3",
                duration: 1500,
                category: "Уход за лицом",
                instructor: "Елена Иванова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
                discount: Discount(
                    percentage: 15,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3 * 24 * 60 * 60), // +3 дня
                    isActive: true
                )
            ),
            VideoLesson(
                id: "lesson_4",
                title: "Антицеллюлитный массаж",
                description: "Эффективные техники антицеллюлитного массажа для коррекции фигуры и улучшения состояния кожи.",
                price: 1800,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=4",
                duration: 2100,
                category: "Коррекция фигуры",
                instructor: "Ольга Сидорова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_5",
                title: "Массаж стоп и рефлексотерапия",
                description: "Техники массажа стоп с элементами рефлексотерапии для расслабления и оздоровления всего организма.",
                price: 1000,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=5",
                duration: 1200,
                category: "Релаксация",
                instructor: "Дмитрий Козлов",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_6",
                title: "Профессиональный макияж",
                description: "Создание идеального макияжа для любого случая. От повседневного до вечернего образа.",
                price: 2000,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=6",
                duration: 2700,
                category: "Макияж",
                instructor: "Мария Волкова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_7",
                title: "Уход за волосами",
                description: "Профессиональные техники ухода за волосами, включая массаж головы и правильное расчесывание.",
                price: 900,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=7",
                duration: 900,
                category: "Уход за волосами",
                instructor: "Ирина Морозова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_8",
                title: "Ароматерапия и массаж",
                description: "Сочетание ароматерапии с массажными техниками для максимального расслабления и оздоровления.",
                price: 2200,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=8",
                duration: 3000,
                category: "Ароматерапия",
                instructor: "Анна Петрова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // Загружаем уроки по одному
        var completedCount = 0
        for lesson in testLessons {
            viewModel.addVideoLesson(lesson) { success in
                DispatchQueue.main.async {
                    completedCount += 1
                    loadedLessonsCount = completedCount
                    
                    if completedCount == testLessons.count {
                        isLoading = false
                        alertMessage = "Успешно загружено \(completedCount) видео уроков в Firebase!"
                        showAlert = true
                    }
                }
            }
        }
    }
    
    private func addTestAdmin() {
        viewModel.addAdmin(phoneNumber: "79001234567") { success in
            DispatchQueue.main.async {
                alertMessage = success ? "Тестовый админ добавлен!" : "Ошибка добавления админа"
                showAlert = true
            }
        }
    }
    
    private func clearAllData() {
        isLoading = true
        
        // Очищаем все видео уроки
        viewModel.databaseRef.child("videoLessons").removeValue { error, _ in
            DispatchQueue.main.async {
                isLoading = false
                if error == nil {
                    alertMessage = "Все данные очищены!"
                } else {
                    alertMessage = "Ошибка очистки данных: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                }
                showAlert = true
            }
        }
    }
}

struct FirebaseDataLoader_Previews: PreviewProvider {
    static var previews: some View {
        FirebaseDataLoader()
    }
}
