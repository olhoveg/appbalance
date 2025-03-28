import SwiftUI
import FirebaseDatabase

// MARK: - Модель услуги
struct VerticalServiceBlockModel: Identifiable, Codable {
    let id: Int
    let title: String
    let category_id: Int
    let price_max: Double?
    let currency: String?
    let duration: Int?
    let image_url: String?
    let comment: String?
}

// MARK: - Модель ответа API
struct VerticalServicesResponse: Codable {
    let data: [VerticalServiceBlockModel]
}

// MARK: - ViewModel
class VerticalServicesViewModel: ObservableObject {
    @Published var services: [VerticalServiceBlockModel] = []
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
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Server error")
                return
            }
            let decoder = JSONDecoder()
            let servicesResponse = try decoder.decode(VerticalServicesResponse.self, from: data)
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

// MARK: - Кэшированное изображение
struct URLImage: View {
    let url: URL
    @State private var image: UIImage? = nil
    private static let cache = NSCache<NSURL, UIImage>()
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(.gray)
                    .opacity(0.5)
                    .overlay(ProgressView())
            }
        }
        .onAppear {
            if let cached = URLImage.cache.object(forKey: url as NSURL) {
                self.image = cached
            } else {
                fetchImage()
            }
        }
    }
    
    func fetchImage() {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImg = UIImage(data: data) {
                URLImage.cache.setObject(uiImg, forKey: url as NSURL)
                DispatchQueue.main.async {
                    self.image = uiImg
                }
            }
        }.resume()
    }
}

// MARK: - Карточка услуги
struct VerticalServiceCardView: View {
    let service: VerticalServiceBlockModel
    @State private var fetchedImageUrl: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var displayImageUrl: String? {
        fetchedImageUrl ?? service.image_url
    }
    
    // Фиксируем ширину карточки под ширину экрана, с отступом 32
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Изображение с фиксированной высотой
            ZStack {
                if let urlString = displayImageUrl, let url = URL(string: urlString) {
                    URLImage(url: url)
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.gray)
                        .opacity(0.5)
                }
            }
            .frame(width: cardWidth, height: 250) // ширина = ширина карточки
            .clipped()
            
            // Заголовок услуги с отступом слева
            Text(service.title)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.leading, 8)
                .frame(width: cardWidth - 16, alignment: .leading)
            
            // Цена и время с отступом перед ценой
            HStack {
                if let price = service.price_max {
                    let currency = service.currency ?? "₽"
                    Text("Цена: \(Int(price)) \(currency)")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.leading, 8)
                }
                Spacer()
                if let duration = service.duration {
                    Text("Время: \(duration / 60) мин")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .frame(width: cardWidth - 16)
            .padding(.bottom, 8)
        }
        // Общее оформление карточки
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 8)
        .onAppear {
            // Загрузить кастомный url из Realtime Database, если есть
            if fetchedImageUrl == nil {
                Task {
                    let url = await verticalGetImageByServiceTitle(service.title)
                    await MainActor.run {
                        fetchedImageUrl = url
                    }
                }
            }
        }
    }
}


// MARK: - Список услуг
struct VerticalServicesView: View {
    @StateObject private var viewModel = VerticalServicesViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.services) { service in
                        NavigationLink(destination: VerticalServiceDetailsView(service: service)) {
                            VerticalServiceCardView(service: service)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Услуги")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.fetchServices()
            }
        }
    }
}

// MARK: - Детальный экран
struct VerticalServiceDetailsView: View {
    let service: VerticalServiceBlockModel
    @State private var detailImageUrl: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var formattedPrice: String? {
        if let price = service.price_max {
            return "\(Int(price)) \(service.currency ?? "₽")"
        }
        return nil
    }
    
    func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) ч \(minutes) мин" : "\(minutes) мин"
    }
    
    // Фиксируем ширину под экран (с отступом), аналогично карточке
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Обёртка для изображения
                ZStack {
                    if let urlString = detailImageUrl ?? service.image_url, let url = URL(string: urlString) {
                        URLImage(url: url)
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                            .opacity(0.5)
                            .frame(width: 50, height: 50)
                    }
                }
                .frame(width: cardWidth, height: 250)
                .clipped()
                
                // Заголовок
                Text(service.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: cardWidth, alignment: .leading)
                
                // Цена и время
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
                .frame(width: cardWidth, alignment: .leading)
                
                // Комментарий
                if let comment = service.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: cardWidth, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(.top, 16)
        }
        .navigationTitle("Услуга")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if (service.image_url ?? "").isEmpty {
                Task {
                    let url = await verticalGetImageByServiceTitle(service.title)
                    detailImageUrl = url
                }
            } else {
                detailImageUrl = service.image_url
            }
        }
    }
}

// MARK: - Поиск картинки в Realtime Database
func verticalGetImageByServiceTitle(_ title: String) async -> String? {
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

// MARK: - Превью
struct VerticalServicesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VerticalServicesView()
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            VerticalServicesView()
        }
        .preferredColorScheme(.dark)
    }
}
