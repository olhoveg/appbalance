import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Модель данных

struct LoyaltyAbonement: Identifiable, Codable, Equatable {
    let id: Int
    let number: String
    let united_balance_services_count: Int?
    let type: LoyaltyAbonementType
    
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

// MARK: - Грамматические функции

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
        return isSolarium ? "минуты" : "сеанса"
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

// MARK: - Карточка абонемента

struct LoyaltyAbonementCardView: View {
    var abonement: LoyaltyAbonement
    @Environment(\.colorScheme) private var colorScheme
    @State private var abonementImageURL: URL?
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var scaleFactor: CGFloat {
        let baseWidth: CGFloat = 375 // Стандартный размер экрана iPhone 11, 12, 13
        return max(0.85, min(screenWidth / baseWidth, 1.2)) // Диапазон масштабирования 0.85 - 1.2
    }
    
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "f2f2f7"
        let fg = "ffffff"
        let urlString = "https://via.placeholder.com/200x150.png?text=Абонемент&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width * 1, 400) // Максимальная ширина 400px на больших экранах
            let cardHeight = cardWidth * 0.4
            
            HStack(spacing: 12 * scaleFactor) {
                AsyncImage(url: abonementImageURL ?? placeholderURL) { phase in
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
                    Text("Абонемент")
                        .font(.system(size: 18 * scaleFactor, weight: .bold))
                    Text("Номер: \(abonement.number)")
                        .font(.system(size: 14 * scaleFactor))
                    
                    if let count = abonement.united_balance_services_count {
                        let solarium = isSolariumAbonement(abonement)
                        Text("\(getRemainingWord(count: count, isSolarium: solarium)): \(count) \(getUnitsEnding(count: count, isSolarium: solarium))")
                            .font(.system(size: 14 * scaleFactor))
                    } else {
                        Text("Осталось: 0 сеансов")
                            .font(.system(size: 14 * scaleFactor))
                    }
                }
                .padding(.trailing, 12 * scaleFactor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
            )
            .frame(width: cardWidth, height: cardHeight)
            .onAppear(perform: fetchAbonementImage)
        }
        .frame(height: 160) // Фиксируем высоту контейнера, чтобы карточки не сжимались
    }
    
    private func fetchAbonementImage() {
        let ref = Database.database().reference(withPath: "abonement_images")
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let imagesDict = snapshot.value as? [String: Any] else { return }
            for (_, value) in imagesDict {
                if let imageInfo = value as? [String: Any],
                   let title = imageInfo["title"] as? String,
                   title == abonement.type.title,
                   let imageUrlString = imageInfo["image_url"] as? String,
                   let url = URL(string: imageUrlString) {
                    DispatchQueue.main.async {
                        abonementImageURL = url
                    }
                    return
                }
            }
        } withCancel: { error in
            print("Ошибка загрузки изображения: \(error.localizedDescription)")
        }
    }
}

    
    

// MARK: - Основной View с вертикальным refreshable

struct LoyaltyAbonementMainView: View {
    @ObservedObject var viewModel: LoyaltyAbonementViewModel
    @AppStorage("userPhone") private var userPhone: String = ""
    
    var body: some View {
        ScrollView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Загрузка абонементов...")
                } else if viewModel.abonements.isEmpty {
                    Text(userPhone.isEmpty ? "Номер клиента не найден" : "Абонементы отсутствуют")
                        .foregroundColor(.secondary)
                } else {
                    // Горизонтальный скролл с карточками
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.abonements) { abonement in
                                LoyaltyAbonementCardView(abonement: abonement)
                                    .frame(width: min(UIScreen.main.bounds.width * 0.9, 400)) // ✅ Ограничиваем максимальную ширину
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            if !userPhone.isEmpty {
                viewModel.fetchAbonements(phone: userPhone)
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
        LoyaltyAbonementMainView(viewModel: LoyaltyAbonementViewModel())
            .preferredColorScheme(.light)
    }
}
