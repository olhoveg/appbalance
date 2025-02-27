import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Модель данных

struct LoyaltyAbonement: Identifiable, Codable, Equatable {
    let id: Int
    let number: String
    let type: LoyaltyAbonementType
    let united_balance_services_count: Int?
    
    struct LoyaltyAbonementType: Codable, Equatable {
        let title: String
    }
}

struct LoyaltyAbonementResponse: Codable {
    let data: [LoyaltyAbonement]
}

// MARK: - ViewModel

class LoyaltyAbonementViewModel: ObservableObject {
    @Published var abonements: [LoyaltyAbonement] = []
    @Published var isLoading = false
    
    private let apiURL = "https://api.yclients.com/api/v1/loyalty/abonements/"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let companyId = "433675"
    
    func fetchAbonements(phone: String) {
        guard !phone.isEmpty else {
            print("Номер телефона пустой")
            return
        }
        guard var urlComponents = URLComponents(string: apiURL) else { return }
        urlComponents.queryItems = [
            URLQueryItem(name: "company_id", value: companyId),
            URLQueryItem(name: "phone", value: phone)
        ]
        guard let url = urlComponents.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }
            if let error = error {
                print("Ошибка при загрузке абонементов: \(error)")
                return
            }
            guard let data = data else {
                print("Нет данных")
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(LoyaltyAbonementResponse.self, from: data)
                DispatchQueue.main.async {
                    self.abonements = decodedResponse.data
                }
            } catch {
                print("Ошибка декодирования: \(error)")
            }
        }.resume()
    }
}

// MARK: - Вспомогательные функции для текста

func isSolariumAbonement(_ abonement: LoyaltyAbonement) -> Bool {
    return abonement.type.title.lowercased().contains("солярий")
}

func getUnitsEnding(count: Int, isSolarium: Bool) -> String {
    let lastDigit = count % 10
    let lastTwoDigits = count % 100
    if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
        return isSolarium ? "минут" : "сеансов"
    } else if lastDigit == 1 {
        return isSolarium ? "минута" : "сеанс"
    } else if (2...4).contains(lastDigit) {
        return isSolarium ? "минуты" : "сеансы"
    } else {
        return isSolarium ? "минут" : "сеансов"
    }
}

func getRemainingWord(count: Int, isSolarium: Bool) -> String {
    let lastDigit = count % 10
    let lastTwoDigits = count % 100
    if isSolarium {
        if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
            return "Осталось"
        } else if lastDigit == 1 {
            return "Осталась"
        } else {
            return "Осталось"
        }
    } else {
        if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
            return "Осталось"
        } else if lastDigit == 1 {
            return "Остался"
        } else {
            return "Осталось"
        }
    }
}

// MARK: - Вид карточки абонемента

struct LoyaltyAbonementCardView: View {
    var abonement: LoyaltyAbonement
    @Environment(\.colorScheme) private var colorScheme
    @State private var cardImageURL: URL?
    
    // Placeholder с via.placeholder.com; можно заменить на локальный asset
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "ffffff"
        let fg = "000000"
        let urlString = "https://via.placeholder.com/100x60.png?text=Абонемент&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: cardImageURL ?? placeholderURL, transaction: Transaction(animation: .easeIn)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 100, height: 60)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 60)
                        .clipped()
                        .cornerRadius(10)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 60)
                        .foregroundColor(.gray)
                        .clipped()
                        .cornerRadius(10)
                @unknown default:
                    EmptyView()
                }
            }
            .padding(.leading, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Абонемент")
                    .font(.title2)
                    .bold()
                Text("Номер карты: \(abonement.number)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                let count = abonement.united_balance_services_count ?? 0
                let solarium = isSolariumAbonement(abonement)
                Text("\(getRemainingWord(count: count, isSolarium: solarium)): \(count) \(getUnitsEnding(count: count, isSolarium: solarium))")
                    .font(.headline)
            }
            .padding(.trailing, 20)
            
            Spacer()
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .onAppear(perform: fetchAbonementImage)
    }
    
    // Загрузка изображения абонемента из Firebase Database
    private func fetchAbonementImage() {
        let ref = Database.database().reference(withPath: "abonement_images")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard let imagesDict = snapshot.value as? [String: Any] else { return }
            for (_, value) in imagesDict {
                if let imageInfo = value as? [String: Any],
                   let title = imageInfo["title"] as? String,
                   title == abonement.type.title,
                   let imageUrlString = imageInfo["image_url"] as? String,
                   let url = URL(string: imageUrlString) {
                    DispatchQueue.main.async {
                        cardImageURL = url
                    }
                    return
                }
            }
        }, withCancel: { error in
            print("Ошибка загрузки изображения: \(error.localizedDescription)")
        })
    }
}

// MARK: - Основной View абонементов

struct LoyaltyAbonementMainView: View {
    @StateObject private var viewModel = LoyaltyAbonementViewModel()
    @AppStorage("userPhone") private var userPhone: String = ""
    @State private var activeIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Загрузка абонементов...")
            } else if viewModel.abonements.isEmpty {
                Text(userPhone.isEmpty ? "Номер клиента не найден" : "Абонементы отсутствуют")
                    .foregroundColor(.secondary)
            } else {
                TabView(selection: $activeIndex) {
                    ForEach(Array(viewModel.abonements.enumerated()), id: \.element.id) { index, abonement in
                        LoyaltyAbonementCardView(abonement: abonement)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .animation(.easeInOut, value: viewModel.abonements)
                .refreshable {
                    if !userPhone.isEmpty {
                        viewModel.fetchAbonements(phone: userPhone)
                    }
                }
            }
        }
        .onAppear {
            if !userPhone.isEmpty {
                viewModel.fetchAbonements(phone: userPhone)
            }
        }
    }
}

// MARK: - Превью

struct LoyaltyAbonementMainView_Previews: PreviewProvider {
    static var previews: some View {
        LoyaltyAbonementMainView()
            .preferredColorScheme(.light)
    }
}
