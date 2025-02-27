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
    
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "f2f2f7"
        let fg = "ffffff"
        let urlString = "https://via.placeholder.com/200x150.png?text=Бонусная+Карта&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: bonusCardImageURL ?? placeholderURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 150)
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
            .frame(width: 160, height: 100)
            .cornerRadius(12)
            .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Бонусная карта")
                    .font(.title2)
                    .bold()
                Text("Номер карты: \(bonusCard.number)")
                    .font(.headline)
                Text("Баланс: \(bonusCard.balance, specifier: "%.2f") ₽")
                    .font(.headline)
            }
            .padding(.trailing, 16)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
        )
        .frame(height: 140)
        .onAppear(perform: fetchBonusCardImage)
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

// MARK: - Основной View бонусных карт

struct LoyaltyBonusCardMainView: View {
    @ObservedObject var viewModel: LoyaltyBonusCardViewModel
    @AppStorage("userPhone") private var userPhone: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Загрузка бонусных карт...")
            } else if viewModel.bonusCards.isEmpty {
                Text(userPhone.isEmpty ? "Номер клиента не найден" : "Бонусные карты отсутствуют")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.bonusCards) { bonusCard in
                            LoyaltyBonusCardView(bonusCard: bonusCard)
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
