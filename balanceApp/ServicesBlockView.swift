import SwiftUI
import FirebaseDatabase

// MARK: - Глобальное кеширование URL услуг (по title)
class ServiceImageURLCache {
    static var shared: [String: String] = [:]
}

/// Асинхронная функция получения URL картинки по названию услуги
/// Если URL уже есть в `ServiceImageURLCache.shared`, возвращаем из кэша
/// Иначе делаем запрос в Firebase, сохраняем результат в кэш, возвращаем
func getImageByServiceTitle(_ title: String) async -> String? {
    // Если URL уже в кэше
    if let cachedURL = ServiceImageURLCache.shared[title], !cachedURL.isEmpty {
        print("Returning cached URL for \(title) из ServiceImageURLCache: \(cachedURL)")
        return cachedURL
    }
    
    // Иначе делаем запрос к Firebase
    return await withCheckedContinuation { continuation in
        let dataRef = Database.database().reference(withPath: "services")
        dataRef.observeSingleEvent(of: .value) { snapshot in
            var imageUrl: String? = nil
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let childData = child.value as? [String: Any],
                   let childTitle = childData["title"] as? String,
                   childTitle == title,
                   let img = childData["imageUrl"] as? String {
                    imageUrl = img
                    break
                }
            }
            // Сохраняем в кэш
            if let finalURL = imageUrl {
                ServiceImageURLCache.shared[title] = finalURL
            }
            print("Fetched imageUrl for title \(title): \(imageUrl ?? "nil")")
            continuation.resume(returning: imageUrl)
        } withCancel: { error in
            print("Error fetching image by service title: \(error)")
            continuation.resume(returning: nil)
        }
    }
}

// MARK: - Модель услуги
struct ServiceBlockModel: Identifiable, Codable {
    let id: Int
    let title: String
    let category_id: Int
    let price_max: Double?
    let currency: String?
    let duration: Int?   // длительность в секундах
    let image_url: String?
    let comment: String?
}

// MARK: - Ответ от API
struct ServicesResponse: Codable {
    let data: [ServiceBlockModel]
}

// MARK: - ViewModel
class ServicesViewModel: ObservableObject {
    @Published var services: [ServiceBlockModel] = []
    
    private let apiURL = "https://api.yclients.com/api/v1/company/433675/services"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let userToken = "9d241fb00061c17a5e2e76a23b214b20"
    
    @MainActor
    func fetchServices() async {
        guard let url = URL(string: apiURL) else {
            print("Invalid URL for services")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey), User \(userToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Server error when fetching services")
                return
            }
            let decoder = JSONDecoder()
            let servicesResponse = try decoder.decode(ServicesResponse.self, from: data)
            self.services = servicesResponse.data
        } catch {
            print("Error fetching services: \(error)")
        }
    }
}

// MARK: - Основной горизонтальный блок
struct ServicesBlockView: View {
    @StateObject private var viewModel = ServicesViewModel()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.services) { service in
                    NavigationLink(destination: ServiceDetailsView(service: service)) {
                        ServiceBlockCardView(service: service)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 10)
        .task {
            await viewModel.fetchServices()
        }
        // Обновление «pull-to-refresh» происходит глобально в MainView
        // поэтому здесь не используем .refreshable
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Карточка услуги
struct ServiceBlockCardView: View {
    let service: ServiceBlockModel
    
    // Храним итоговый URL картинки (полученный из модели или через Firebase)
    @State private var finalImageURL: String? = nil
    
    // Храним само UIImage, загружаем через ImageCache
    @State private var loadedImage: UIImage? = nil
    @State private var isLoadingImage = false
    
    @EnvironmentObject var imageCache: ImageCache  // Передаём EnvironmentObject
    @Environment(\.colorScheme) var colorScheme
    
    // Если в модели есть image_url – используем его сразу,
    // иначе дождёмся getImageByServiceTitle
    var initialURL: String? {
        service.image_url
    }
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white
    }
    
    var priceTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let loadedImage = loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 100)
                        .clipped()
                } else if isLoadingImage {
                    ProgressView()
                        .frame(width: 160, height: 100)
                } else {
                    // Плейсхолдер
                    Color.gray.opacity(0.2)
                        .frame(width: 160, height: 100)
                }
                
                // Полоса с названием
                if !service.title.isEmpty {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 160, height: 30)
                    Text(service.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.leading, 6)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Цена, если есть
            if let price = service.price_max {
                Text("Цена: \(Int(price)) ₽")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(priceTextColor)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
        .padding(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
        .frame(width: 160, height: 160, alignment: .top)
        .background(cardBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            loadFinalURL()
        }
        // Если вдруг что-то меняется в initialURL (маловероятно), заново грузим
        .onChange(of: initialURL) { _ in
            loadFinalURL()
        }
        // Если вдруг finalImageURL меняется, перезагружаем саму картинку
        .onChange(of: finalImageURL) { newValue in
            loadImage(from: newValue)
        }
    }
    
    /// Загружаем итоговый URL либо из модели (если есть), либо через getImageByServiceTitle
    private func loadFinalURL() {
        // Если уже загружали URL, не повторяем
        guard finalImageURL == nil else {
            loadImage(from: finalImageURL)
            return
        }
        
        if let directURL = initialURL, !directURL.isEmpty {
            // URL уже есть в модели
            finalImageURL = directURL
        } else {
            // URL в модели нет, ищем в Firebase
            Task {
                let fetched = await getImageByServiceTitle(service.title)
                await MainActor.run {
                    finalImageURL = fetched
                }
            }
        }
    }
    
    /// Вызываем ImageCache для загрузки конечного изображения
    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        isLoadingImage = true
        imageCache.loadImage(from: urlString) { uiImage in
            self.loadedImage = uiImage
            self.isLoadingImage = false
        }
    }
}

// MARK: - Детальный экран
struct ServiceDetailsView: View {
    let service: ServiceBlockModel
    @State private var detailURL: String? = nil
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var imageCache: ImageCache
    
    func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h) ч \(m) мин" : "\(m) мин"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовочное изображение
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipped()
                    } else if isLoading {
                        ProgressView().frame(height: 250)
                    } else {
                        Color.gray.frame(height: 250)
                            .overlay(Text("No image").foregroundColor(.white))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Текстовая часть
                VStack(alignment: .leading, spacing: 8) {
                    Text(service.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    if let p = service.price_max {
                        Text("Цена: \(Int(p)) ₽")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    if let d = service.duration {
                        Text("Время: \(formattedDuration(d))")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    if let c = service.comment, !c.isEmpty {
                        Text(c)
                            .font(.body)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                .padding(.vertical, 4)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Услуга")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            loadFinalURL()
        }
        .onChange(of: detailURL) { newValue in
            loadDetailImage(newValue)
        }
    }
    
    private func loadFinalURL() {
        // Если модель уже содержит image_url
        if let direct = service.image_url, !direct.isEmpty {
            detailURL = direct
        } else {
            Task {
                let fetched = await getImageByServiceTitle(service.title)
                await MainActor.run {
                    detailURL = fetched
                }
            }
        }
    }
    
    private func loadDetailImage(_ urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        isLoading = true
        imageCache.loadImage(from: urlString) { uiImage in
            loadedImage = uiImage
            isLoading = false
        }
    }
}

// MARK: - Превью
struct ServicesBlockView_Previews: PreviewProvider {
    static var previews: some View {
        // В реальном проекте нужно .environmentObject(ImageCache.shared)
        NavigationView {
            ServicesBlockView()
                .environmentObject(ImageCache.shared)
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            ServicesBlockView()
                .environmentObject(ImageCache.shared)
        }
        .preferredColorScheme(.dark)
    }
}
