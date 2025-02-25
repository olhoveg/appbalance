import SwiftUI
import FirebaseDatabase

// MARK: - Модель услуги (ServiceBlockModel)
struct ServiceBlockModel: Identifiable, Codable {
    let id: Int
    let title: String
    let category_id: Int
    let price_max: Double?
    let currency: String?
    let duration: Int?  // предполагается, что длительность указана в секундах
    let image_url: String?
    let comment: String?
}

// MARK: - Модель ответа API
struct ServicesResponse: Codable {
    let data: [ServiceBlockModel]
}

// MARK: - ViewModel для загрузки услуг
class ServicesViewModel: ObservableObject {
    @Published var services: [ServiceBlockModel] = []
    @Published var isRefreshing = false
    
    private let apiURL = "https://api.yclients.com/api/v1/company/433675/services"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let userToken = "9d241fb00061c17a5e2e76a23b214b20"
    
    @MainActor
    func fetchServices() async {
        guard let url = URL(string: apiURL) else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey), User \(userToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Server error")
                return
            }
            let decoder = JSONDecoder()
            let servicesResponse = try decoder.decode(ServicesResponse.self, from: data)
            self.services = servicesResponse.data
        } catch {
            print("Error fetching services: \(error)")
        }
    }

    
    func refresh() async {
        isRefreshing = true
        await fetchServices()
        DispatchQueue.main.async {
            self.isRefreshing = false
        }
    }
}

// MARK: - Глобальная функция для получения URL изображения по названию услуги из Realtime Database
func getImageByServiceTitle(_ title: String) async -> String? {
    await withCheckedContinuation { continuation in
        let dataRef = Database.database().reference(withPath: "services")
        dataRef.observeSingleEvent(of: .value, with: { snapshot in
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
            print("Fetched imageUrl for title \(title): \(imageUrl ?? "nil")")
            continuation.resume(returning: imageUrl)
        }, withCancel: { error in
            print("Error fetching image by service title: \(error)")
            continuation.resume(returning: nil)
        })
    }
}

// MARK: - Основной горизонтальный блок услуг
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
        .refreshable {
            await viewModel.refresh()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Карточка услуги
struct ServiceBlockCardView: View {
    let service: ServiceBlockModel
    @State private var fetchedImageUrl: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Используем либо URL из базы, либо тот, что есть в модели
    var displayImageUrl: String? {
        fetchedImageUrl ?? service.image_url
    }
    
    // Фон карточки: тёмная тема – systemGray6, светлая – белый
    var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white
    }
    
    // Цвет текста цены: тёмная тема – белый, светлая – чёрный
    var priceTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                // Placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 100)
                
                if let urlString = displayImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url, transaction: Transaction(animation: .none)) { phase in
                        switch phase {
                        case .empty:
                            EmptyView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 100)
                                .clipped()
                        case .failure:
                            Color.gray.frame(width: 160, height: 100)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    ZStack {
                        Color.gray.frame(width: 160, height: 100)
                        Text("No image")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                
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
            
            // Цена выводится ниже изображения
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
            if fetchedImageUrl == nil {
                Task {
                    let url = await getImageByServiceTitle(service.title)
                    await MainActor.run {
                        
                        fetchedImageUrl = url
                    }
                }
            }
        }
    }
}

// MARK: - Детальный экран услуги
struct ServiceDetailsView: View {
    let service: ServiceBlockModel
    @State private var detailImageUrl: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Форматирование цены: если есть цена, выводим как целое число с ₽
    var formattedPrice: String? {
        if let price = service.price_max {
            return "\(Int(price)) ₽"
        }
        return nil
    }
    
    // Конвертация длительности (секунд) в часы и минуты
    func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Изображение услуги: используем detailImageUrl или service.image_url
                if let urlString = detailImageUrl ?? service.image_url, let url = URL(string: urlString) {
                    AsyncImage(url: url, transaction: Transaction(animation: .none)) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipped()
                        } else if phase.error != nil {
                            Color.gray.frame(height: 250)
                        } else {
                            ProgressView().frame(height: 250)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ZStack {
                        Color.gray.frame(height: 250)
                        Text("No image")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Заголовок услуги
                Text(service.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                // Блок информации: цена и длительность
                VStack(alignment: .leading, spacing: 8) {
                    if let formattedPrice = formattedPrice {
                        Text("Цена: \(formattedPrice)")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    if let duration = service.duration {
                        Text("Время: \(formattedDuration(duration))")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                .padding(.vertical, 4)
                
                // Текст услуги (комментарий), если есть
                if let comment = service.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.body)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Услуга")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if (service.image_url ?? "").isEmpty {
                Task {
                    let url = await getImageByServiceTitle(service.title)
                    detailImageUrl = url
                }
            } else {
                detailImageUrl = service.image_url
            }
        }
    }
}

// MARK: - Превью
struct ServicesBlockView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ServicesBlockView()
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            ServicesBlockView()
        }
        .preferredColorScheme(.dark)
    }
}
