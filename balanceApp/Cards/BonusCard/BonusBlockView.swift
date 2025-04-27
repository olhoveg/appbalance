import SwiftUI
import FirebaseDatabase

private let API_KEY = "88fnh8jbmt44er5y28nj"

struct BonusBlockView: View {
    @State private var bonusCards: [BonusCard] = []
    @State private var activeIndex: Int = 0
    @State private var isLoading = true        // стартуем в режиме загрузки (скелетон)
    @State private var phoneNumber: String = ""
    
    var body: some View {
        // Убираем NavigationView, так как родительские вкладки (TabView) уже могут иметь свою NavigationView
        ZStack {
            // Явно задаём фон
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if !phoneNumber.isEmpty {
                        if bonusCards.isEmpty {
                            if !isLoading {
                                Text("У вас нет бонусных карт")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 20)
                            }
                        } else {
                            TabView(selection: $activeIndex) {
                                ForEach(bonusCards) { card in
                                    BonusBlockCardView(bonusCard: card)
                                        .padding(.horizontal, 20)
                                        .tag(card.id)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 300)
                            .animation(.easeInOut, value: activeIndex)
                        }
                    } else {
                        // Нет номера телефона
                        Text("Бонусные карты недоступны. Пожалуйста, авторизуйтесь.")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            // Загружаем телефон и сразу стартуем скелетон
            if let phone = UserDefaults.standard.string(forKey: "userPhone") {
                phoneNumber = phone
                fetchBonusCards()
            }
        }
        .refreshable {
            fetchBonusCards()
        }
    }
    
    private func fetchBonusCards() {
        guard !phoneNumber.isEmpty else { return }
        // Устанавливаем флаг загрузки, чтобы сразу показать скелетон
        DispatchQueue.main.async {
            isLoading = true
        }
        
        let groupId = "415038"
        let companyId = "433675"
        let urlString = "https://api.yclients.com/api/v1/loyalty/cards/\(phoneNumber)/\(groupId)/\(companyId)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { isLoading = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(API_KEY), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("Ошибка при получении бонусных карт: \(error.localizedDescription)")
                    isLoading = false
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BonusAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    bonusCards = response.data
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Ошибка декодирования бонусных карт: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }.resume()
    }
}




struct PaginationView: View {
    let dots: Int
    let activeIndex: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dots, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: activeIndex)
            }
        }
        .padding(.top, 10)
    }
}




