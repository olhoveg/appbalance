import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Модель данных

struct LoyaltyBonusCard: Identifiable, Codable, Equatable {
    let id: Int
    let number: String
    let balance: Double
    let type: LoyaltyBonusCardType
    
    struct LoyaltyBonusCardType: Codable, Equatable {
        let title: String
    }
}

struct LoyaltyBonusCardResponse: Codable {
    let success: Bool
    let data: [LoyaltyBonusCard]
}

// MARK: - ViewModel

class LoyaltyBonusCardViewModel: ObservableObject {
    @Published var bonusCards: [LoyaltyBonusCard] = []
    @Published var isLoading = false
    
    private let apiURL = "https://api.yclients.com/api/v1/loyalty/cards/"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let companyId = "433675"
    private let groupId = "415038"
    
    func fetchBonusCards(phone: String) {
        guard !phone.isEmpty else {
            print("Номер телефона пустой")
            return
        }
        let urlString = "\(apiURL)\(phone)/\(groupId)/\(companyId)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }
            
            if let error = error {
                print("Ошибка при загрузке бонусных карт: \(error)")
                return
            }
            
            guard let data = data else {
                print("Нет данных")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(LoyaltyBonusCardResponse.self, from: data)
                DispatchQueue.main.async {
                    self.bonusCards = decodedResponse.data
                }
            } catch {
                print("Ошибка декодирования бонусных карт: \(error.localizedDescription)")
            }
        }.resume()
    }
}

// MARK: - Карточка бонусной карты

struct LoyaltyBonusCardView: View {
    var bonusCard: LoyaltyBonusCard
    @Environment(\.colorScheme) private var colorScheme
    @State private var bonusCardImageURL: URL?
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var scaleFactor: CGFloat {
        let baseWidth: CGFloat = 375 // Базовый размер экрана (iPhone 11, 12, 13)
        return max(0.85, min(screenWidth / baseWidth, 1.2)) // Масштабирование от 0.85 до 1.2
    }
    
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "f2f2f7"
        let fg = "ffffff"
        let urlString = "https://via.placeholder.com/200x150.png?text=Бонусная+Карта&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width * 1, 400) // Максимальная ширина 400px
            let cardHeight = cardWidth * 0.4
            
            HStack(spacing: 12 * scaleFactor) {
                AsyncImage(url: bonusCardImageURL ?? placeholderURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 140 * scaleFactor, height: 90 * scaleFactor)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(.gray)
                    @unknown default:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 140 * scaleFactor, height: 90 * scaleFactor)
                .cornerRadius(12 * scaleFactor)
                .clipped()
                
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    Text("Бонусная карта")
                        .font(.system(size: 18 * scaleFactor, weight: .bold))
                    Text("Номер: \(bonusCard.number)")
                        .font(.system(size: 14 * scaleFactor))
                    Text("Баланс: \(Int(bonusCard.balance)) ₽")
                        .font(.system(size: 14 * scaleFactor))
                }
                .padding(.trailing, 12 * scaleFactor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
            )
            .frame(width: cardWidth, height: cardHeight)
            .onAppear(perform: fetchBonusCardImage)
        }
        .frame(height: 160) // Фиксируем высоту контейнера, чтобы карточки не сжимались
    }
    
    private func fetchBonusCardImage() {
        let ref = Database.database().reference(withPath: "bonuscard_image")
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let imagesDict = snapshot.value as? [String: Any] else { return }
            for (_, value) in imagesDict {
                if let imageInfo = value as? [String: Any],
                   let title = imageInfo["title"] as? String,
                   title == bonusCard.type.title,
                   let imageUrlString = imageInfo["image_url"] as? String,
                   let url = URL(string: imageUrlString) {
                    DispatchQueue.main.async {
                        bonusCardImageURL = url
                    }
                    return
                }
            }
        } withCancel: { error in
            print("Ошибка загрузки изображения бонусной карты: \(error.localizedDescription)")
        }
    }
}

// MARK: - Skeleton для бонусных карт
struct SkeletonBonusCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 400)
            let height = width * 0.4
            HStack(spacing: 12) {
                // Заглушка для изображения
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width * 0.35, height: height * 0.9)
                // Заглушки для текста
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width * 0.4, height: 16)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width * 0.3, height: 14)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width * 0.35, height: 14)
                }
                Spacer()
            }
            .padding()
            .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
            .cornerRadius(15)
            .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 5)
        }
        .frame(height: 160)
        .padding(.horizontal, 16)
    }
}

// MARK: - Основной View бонусных карт

struct LoyaltyBonusCardMainView: View {
    @ObservedObject var viewModel: LoyaltyBonusCardViewModel
    @AppStorage("userPhone") private var userPhone: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBonusCardView()
                                .frame(width: min(UIScreen.main.bounds.width * 0.9, 400), height: 160)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else if viewModel.bonusCards.isEmpty {
                if userPhone.isEmpty {
                    Text("Авторизуйтесь, чтобы увидеть бонусные карты")
                        .foregroundColor(.secondary)
                } else {
                    Text("У вас нет бонусных карт")
                        .foregroundColor(.secondary)
                }
            
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.bonusCards) { bonusCard in
                            LoyaltyBonusCardView(bonusCard: bonusCard)
                                .frame(width: min(UIScreen.main.bounds.width * 0.9, 400)) // ✅ Ограничиваем максимальную ширину
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .onAppear {
            if !userPhone.isEmpty {
                viewModel.fetchBonusCards(phone: userPhone)
            }
        }
    }
}

// MARK: - Превью

struct LoyaltyBonusCardMainView_Previews: PreviewProvider {
    static var previews: some View {
        LoyaltyBonusCardMainView(viewModel: LoyaltyBonusCardViewModel())
            .preferredColorScheme(.light)
    }
}
