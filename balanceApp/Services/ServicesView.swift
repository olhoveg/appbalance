import SwiftUI
import FirebaseDatabase
import UIKit
import AppMetricaCore

// MARK: - Кэширование URL изображений для Vertical Services
class VerticalServiceImageURLCache {
    static var shared: [String: String] = [:]
}

// MARK: - Модель услуги и модель ответа API
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

struct VerticalServicesResponse: Codable {
    let data: [VerticalServiceBlockModel]
}

// MARK: - ViewModel для VerticalServicesView
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

// MARK: - Кэш изображений
struct ServicesCachedImageEntry {
    let image: UIImage
    let timestamp: Date
}

class ServicesImageCache: ObservableObject {
    static let shared = ServicesImageCache()
    @Published var cachedImages: [String: ServicesCachedImageEntry] = [:]

    let expirationInterval: TimeInterval = 3600

    func loadImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        // Если изображение уже в кэше, возвращаем его без задержки
        if let entry = cachedImages[url] {
            let elapsed = Date().timeIntervalSince(entry.timestamp)
            if elapsed < expirationInterval {
                print("ServicesImageCache: Возвращаем закэшированное изображение для URL: \(url)")
                completion(entry.image)
                return
            } else {
                print("ServicesImageCache: Закэшированное изображение устарело для URL: \(url)")
                cachedImages.removeValue(forKey: url)
            }
        }

        guard let imageUrl = URL(string: url) else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: imageUrl),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.cachedImages[url] = ServicesCachedImageEntry(image: image, timestamp: Date())
                    print("ServicesImageCache: Изображение успешно загружено для URL: \(url)")
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

// MARK: - Placeholder для карточки услуги (Skeleton)
struct VerticalServiceCardSkeletonPlaceholderView: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 250)
            .shimmer()
    }
}

// MARK: - Получение URL изображения по названию услуги из Firebase
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
            print("Fetched imageUrl for \(title): \(imageUrl ?? "nil")")
            continuation.resume(returning: imageUrl)
        }, withCancel: { error in
            print("Error fetching image by service title: \(error)")
            continuation.resume(returning: nil)
        })
    }
}

// MARK: - Карточка услуги (в списке)
// Здесь при нажатии передаётся уже загруженное изображение (loadedImage) в детальное представление, если оно имеется.
struct VerticalServiceCardView: View {
    let service: VerticalServiceBlockModel
    @State private var finalImageUrl: String? = nil
    @State private var loadedImage: UIImage? = nil
    @State private var isLoadingImage = false
    @Environment(\.colorScheme) var colorScheme

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }

    var body: some View {
        NavigationLink(destination: VerticalServiceDetailsView(service: service, preloadedImage: loadedImage)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if isLoadingImage {
                        VerticalServiceCardSkeletonPlaceholderView()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: cardWidth, height: 250)
                .clipped()

                Text(service.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.leading, 8)
                    .frame(width: cardWidth - 16, alignment: .leading)

                HStack {
                    if let price = service.price_max {
                        Text("Цена: \(Int(price)) \(service.currency ?? "₽")")
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
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding(.vertical, 8)
        }
        .onAppear {
            loadFinalURL()
        }
        .onChange(of: finalImageUrl) {
            loadImage(from: finalImageUrl)
        }
    }

    private func loadFinalURL() {
        if let direct = service.image_url, !direct.isEmpty {
            finalImageUrl = direct
        } else {
            Task {
                let url = await verticalGetImageByServiceTitle(service.title)
                await MainActor.run {
                    finalImageUrl = url
                }
            }
        }
    }

    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        if let cached = ServicesImageCache.shared.cachedImages[urlString]?.image {
            self.loadedImage = cached
        } else {
            isLoadingImage = true
            ServicesImageCache.shared.loadImage(from: urlString) { image in
                DispatchQueue.main.async {
                    self.loadedImage = image
                    self.isLoadingImage = false
                }
            }
        }
    }
}

// MARK: - Детальное отображение услуги
// Добавлен параметр preloadedImage для мгновенного отображения картинки, если она уже была загружена из карточки.
struct VerticalServiceDetailsView: View {
    let service: VerticalServiceBlockModel
    let preloadedImage: UIImage?  // Переданное предварительно загруженное изображение
    @State private var detailImageUrl: String?
    @State private var loadedImage: UIImage? = nil
    @State private var isLoadingImage = false
    @Environment(\.presentationMode) private var presentationMode
    @State private var showBackButton = false
    
    @Environment(\.colorScheme) var colorScheme

    init(service: VerticalServiceBlockModel, preloadedImage: UIImage? = nil) {
        self.service = service
        self.preloadedImage = preloadedImage
        if let directURL = service.image_url, !directURL.isEmpty {
            _detailImageUrl = State(initialValue: directURL)
        } else {
            _detailImageUrl = State(initialValue: nil)
        }
        if let preloaded = preloadedImage {
            _loadedImage = State(initialValue: preloaded)
        } else {
            _loadedImage = State(initialValue: nil)
        }
    }

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

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Зона для изображения
                    ZStack {
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: 250)
                                .clipped()
                        } else if isLoadingImage {
                            ProgressView()
                                .frame(width: cardWidth, height: 250)
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: cardWidth, height: 250)
                        }
                    }
                    .frame(width: cardWidth, height: 250)
                    .clipped()
                    .padding(.leading, 16)

                    // Цена и время
                    HStack {
                        if let priceStr = formattedPrice {
                            Text("Цена: \(priceStr)")
                        }
                        Spacer()
                        if let duration = service.duration {
                            Text("Время: \(formattedDuration(duration))")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemGray6))
                    )
                    .frame(width: cardWidth)
                    .padding(.leading, 16)

                    // Комментарий
                    if let comment = service.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.body)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .frame(width: cardWidth, alignment: .leading)
                            .padding(.leading, 16)
                    }

                    Spacer()

                    // Detection area: shows back button when reached
                    Color.clear
                        .frame(height: 1)
                        .background(
                            GeometryReader { proxy in
                                let minY = proxy.frame(in: .named("scroll")).minY
                                Color.clear
                                    .onChange(of: minY) {
                                        // Compare to viewport height
                                        let viewportHeight = UIScreen.main.bounds.height
                                        if minY < viewportHeight {
                                            withAnimation(.easeInOut) { showBackButton = true }
                                        } else {
                                            withAnimation(.easeInOut) { showBackButton = false }
                                        }
                                    }
                            }
                        )
                }
                    .padding(EdgeInsets(
                        top: 16,
                        leading: 0,
                        bottom: showBackButton ? 80 : 12,
                        trailing: 0
                    ))
            }
            .coordinateSpace(name: "scroll")
            .scrollIndicators(.hidden)

            // Back button overlay
            if showBackButton {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Назад")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(service.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            let priceValue = Int(service.price_max ?? 0)
            let durationMinutes = (service.duration ?? 0) / 60
            AppMetrica.reportEvent(
                name: "Пользователь выбрал услугу",
                parameters: [
                    "название": service.title,
                    "цена": priceValue,
                    "длительность (мин)": durationMinutes
                ]
            )
            if detailImageUrl == nil || detailImageUrl?.isEmpty == true {
                Task {
                    let url = await verticalGetImageByServiceTitle(service.title)
                    await MainActor.run {
                        detailImageUrl = url
                        loadImageIfNeeded()
                    }
                }
            } else {
                loadImageIfNeeded()
            }
        }
        .onChange(of: detailImageUrl) {
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard let urlString = detailImageUrl, !urlString.isEmpty else { return }
        if let cached = ServicesImageCache.shared.cachedImages[urlString]?.image {
            self.loadedImage = cached
            return
        }
        isLoadingImage = true
        ServicesImageCache.shared.loadImage(from: urlString) { image in
            DispatchQueue.main.async {
                withTransaction(Transaction(animation: nil)) {
                    self.loadedImage = image
                }
                self.isLoadingImage = false
            }
        }
    }
}

// MARK: - Основной экран с перечнем услуг
enum SortOption: String, CaseIterable, Identifiable {
    case none = "Без сортировки"
    case price = "По цене"
    case duration = "По времени"

    var id: String { self.rawValue }
}

struct VerticalServicesView: View {
    @StateObject private var viewModel = VerticalServicesViewModel()
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .none
    @State private var isSearchPresented = false
    @State private var searchDebounceWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationView {
            List {
                // Сегментированный контроль сортировки
                if isSearchPresented {
                    Picker("Сортировка", selection: $selectedSortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                }
                
                // Сами услуги
                ForEach(filteredAndSortedServices) { service in
                    VerticalServiceCardView(service: service)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Услуги")
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск услуг"
            )
            .onChange(of: searchText) { query in
                // Cancel previous pending event
                searchDebounceWorkItem?.cancel()
                // Create new work item
                let workItem = DispatchWorkItem {
                    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanQuery.isEmpty else { return }
                    AppMetrica.reportEvent(
                        name: "Пользователь воспользовался поиском услуг",
                        parameters: ["запрос": cleanQuery]
                    )
                }
                // Store and schedule after 1 second of no typing
                searchDebounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            }
            .onChange(of: selectedSortOption) { option in
                switch option {
                case .price:
                    AppMetrica.reportEvent(name: "Пользователь отфильтровал услуги по цене")
                case .duration:
                    AppMetrica.reportEvent(name: "Пользователь отфильтровал услуги по времени")
                default:
                    break
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.fetchServices()
            }
        }
    }

    private var filteredAndSortedServices: [VerticalServiceBlockModel] {
        let filtered = viewModel.services.filter { service in
            guard !searchText.isEmpty else { return true }
            
            let lowercasedSearch = searchText.lowercased()
            let titleMatches = service.title.lowercased().contains(lowercasedSearch)
 
            let priceMatches: Bool
            if let price = service.price_max {
                priceMatches = "\(Int(price))".contains(lowercasedSearch)
            } else {
                priceMatches = false
            }
 
            let durationMatches: Bool
            if let duration = service.duration {
                let minutes = duration / 60
                let normalizedSearch = lowercasedSearch
                    .replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: "минут", with: "мин")
                    .replacingOccurrences(of: "минута", with: "мин")
                    .replacingOccurrences(of: "мин", with: "м")
                    .replacingOccurrences(of: "часов", with: "ч")
                    .replacingOccurrences(of: "часа", with: "ч")
                    .replacingOccurrences(of: "час", with: "ч")
                    .replacingOccurrences(of: " ", with: "")

                let hourRegex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]?\d*)?)ч"#)
                let minRegex = try? NSRegularExpression(pattern: #"(\d+)м"#)
                
                var totalSearchMinutes = 0
                
                if let hourMatch = hourRegex?.firstMatch(in: normalizedSearch, range: NSRange(location: 0, length: normalizedSearch.utf16.count)),
                   let hourRange = Range(hourMatch.range(at: 1), in: normalizedSearch) {
                    let hourStr = String(normalizedSearch[hourRange]).replacingOccurrences(of: ",", with: ".")
                    if let hourValue = Double(hourStr) {
                        totalSearchMinutes += Int(hourValue * 60)
                    }
                }
                
                if let minMatch = minRegex?.firstMatch(in: normalizedSearch, range: NSRange(location: 0, length: normalizedSearch.utf16.count)),
                   let minRange = Range(minMatch.range(at: 1), in: normalizedSearch) {
                    if let minValue = Int(normalizedSearch[minRange]) {
                        totalSearchMinutes += minValue
                    }
                }

                durationMatches = totalSearchMinutes == minutes
            } else {
                durationMatches = false
            }
 
            return titleMatches || priceMatches || durationMatches
        }
        switch selectedSortOption {
        case .price:
            return filtered.sorted { ($0.price_max ?? 0) < ($1.price_max ?? 0) }
        case .duration:
            return filtered.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .none:
            return filtered
        }
    }
}

// MARK: - Превью для SwiftUI
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
