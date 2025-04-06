import SwiftUI
import FirebaseDatabase

// MARK: - Кастомный Shape для округления отдельных углов
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Модель рекомендации
struct Recommendation: Identifiable {
    let id: String
    let image: String
    let category: String
    let title: String
    let description: String?   // Описание в формате HTML (если есть)
}

// MARK: - ViewModel для загрузки рекомендаций из Firebase
class RecommendationsViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    
    func fetchRecommendations() {
        let ref = Database.database().reference(withPath: "recommendations/recommendations")
        ref.observeSingleEvent(of: .value) { snapshot in
            var fetched: [Recommendation] = []
            
            if let dict = snapshot.value as? [String: Any] {
                for (key, data) in dict {
                    if key == "id" { continue }
                    if let item = data as? [String: Any],
                       let image = item["image"] as? String,
                       let category = item["category"] as? String,
                       let title = item["title"] as? String {
                        let description = item["description"] as? String
                        let recommendation = Recommendation(id: key,
                                                            image: image,
                                                            category: category,
                                                            title: title,
                                                            description: description)
                        fetched.append(recommendation)
                    }
                }
            } else if let array = snapshot.value as? [[String: Any]] {
                for item in array {
                    if let image = item["image"] as? String,
                       let category = item["category"] as? String,
                       let title = item["title"] as? String {
                        let id: String
                        if let idStr = item["id"] as? String {
                            id = idStr
                        } else if let idInt = item["id"] as? Int {
                            id = String(idInt)
                        } else {
                            id = UUID().uuidString
                        }
                        let description = item["description"] as? String
                        let recommendation = Recommendation(id: id,
                                                            image: image,
                                                            category: category,
                                                            title: title,
                                                            description: description)
                        fetched.append(recommendation)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.recommendations = fetched
            }
        }
    }
}

// MARK: - Блок рекомендаций в SwiftUI
struct RecommendationsBlockView: View {
    @StateObject var viewModel = RecommendationsViewModel()
    
    var body: some View {
        VStack {
            if viewModel.recommendations.isEmpty {
                // Если рекомендаций нет – сразу показываем сообщение без пустого пространства
                Text("Рекомендации недоступны. Пожалуйста, авторизуйтесь или обновите экран.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.recommendations) { recommendation in
                            NavigationLink(destination: RecommendationDetailsView(recommendation: recommendation)) {
                                RecommendationItemView(recommendation: recommendation)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.vertical, 10)
            }
        }
        .onAppear {
            viewModel.fetchRecommendations()
        }
        // Убрали .refreshable, чтобы при горизонтальном листании блок оставался статичным
    }
}

// MARK: - Отдельная карточка рекомендации с бесшовной загрузкой изображения через ImageCache
struct RecommendationItemView: View {
    let recommendation: Recommendation
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var imageCache = ImageCache.shared
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground)
    }
    
    var body: some View {
        ZStack {
            cardBackground
                .cornerRadius(10)
                .shadow(radius: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                // Изображение
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 120)
                            .cornerRadius(10, corners: [.topLeft, .topRight])
                    } else if isLoading {
                        ProgressView()
                            .frame(width: 160, height: 120)
                    } else {
                        Color.gray
                            .frame(width: 160, height: 120)
                            .cornerRadius(10, corners: [.topLeft, .topRight])
                    }
                }
                
                // Категория
                Text(recommendation.category)
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 4)
                
                // Заголовок
                Text(recommendation.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .frame(width: 160, height: 200, alignment: .top)
        }
        .frame(width: 160, height: 200)
        .padding(.vertical, 4)
        .onAppear {
            loadRecommendationImage()
        }
    }
    
    private func loadRecommendationImage() {
        guard !recommendation.image.isEmpty else { return }
        isLoading = true
        imageCache.loadImage(from: recommendation.image) { image in
            DispatchQueue.main.async {
                self.loadedImage = image
                self.isLoading = false
            }
        }
    }
}

// MARK: - Детальный экран рекомендации (HTML → AttributedString)
struct RecommendationDetailsView: View {
    let recommendation: Recommendation
    @Environment(\.colorScheme) var colorScheme
    
    func renderedDescription() -> AnyView {
        guard let descriptionHTML = recommendation.description,
              !descriptionHTML.isEmpty else {
            return AnyView(EmptyView())
        }
        if #available(iOS 15.0, *) {
            if let data = descriptionHTML.data(using: .utf8),
               let nsAttributedString = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
               ) {
                var attributedString = AttributedString(nsAttributedString)
                attributedString.font = .systemFont(ofSize: 18)
                let textColor: Color = (colorScheme == .dark) ? .white : .black
                attributedString.foregroundColor = textColor
                return AnyView(Text(attributedString)
                    .padding(.top, 8))
            } else {
                return AnyView(Text(descriptionHTML)
                    .font(.system(size: 18))
                    .foregroundColor(Color(UIColor.label))
                    .padding(.top, 8))
            }
        } else {
            return AnyView(Text(descriptionHTML)
                .font(.system(size: 18))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 8))
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                AsyncImage(url: URL(string: recommendation.image)) { phase in
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
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(recommendation.category)
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    
                    Text(recommendation.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(UIColor.label))
                    
                    renderedDescription()
                }
                .padding()
            }
        }
        .navigationTitle("Детали")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Превью
struct RecommendationsBlockView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecommendationsBlockView()
                .environmentObject(ImageCache.shared)
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            RecommendationsBlockView()
                .environmentObject(ImageCache.shared)
        }
        .preferredColorScheme(.dark)
    }
}
