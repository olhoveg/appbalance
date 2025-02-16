import SwiftUI
import FirebaseDatabase

private let API_KEY = "88fnh8jbmt44er5y28nj" // Ваш API ключ

struct BonusBlockView: View {
    @State private var bonusCards: [BonusCard] = []
    @State private var activeIndex: Int = 0
    @State private var isLoading = false
    @State private var phoneNumber: String = ""
    
    let screenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                    } else if bonusCards.isEmpty {
                        Text("Нет бонусных карт")
                    } else {
                        TabView(selection: $activeIndex) {
                            ForEach(bonusCards) { card in
                                BonusBlockCardView(bonusCard: card)
                                    .padding(.horizontal, 10)
                                    .tag(card.id)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .frame(height: 250)
                        
                        PaginationView(dots: bonusCards.count, activeIndex: activeIndex)
                    }
                }
                .padding()
            }
            .navigationTitle("Бонусная карта")
            .onAppear {
                if let phone = UserDefaults.standard.string(forKey: "userPhone") {
                    phoneNumber = phone
                    fetchBonusCards()
                } else {
                    print("Номер телефона не найден")
                }
            }
            .refreshable {
                fetchBonusCards()
            }
        }
    }
    
    private func fetchBonusCards() {
        guard !phoneNumber.isEmpty else {
            print("Номер телефона пуст")
            return
        }
        isLoading = true
        
        let groupId = "415038"
        let companyId = "433675"
        let urlString = "https://api.yclients.com/api/v1/loyalty/cards/\(phoneNumber)/\(groupId)/\(companyId)"
        guard let url = URL(string: urlString) else {
            print("Неверный URL")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(API_KEY), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            if let error = error {
                print("Ошибка при получении бонусных карт: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                // Если API не возвращает даты, можно не настраивать dateDecodingStrategy
                let response = try decoder.decode(BonusAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    bonusCards = response.data
                }
            } catch {
                print("Ошибка декодирования бонусных карт: \(error.localizedDescription)")
            }
        }.resume()
    }
}

struct PaginationView: View {
    let dots: Int
    let activeIndex: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dots, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.black : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 8)
    }
}

struct BonusBlockView_Previews: PreviewProvider {
    static var previews: some View {
        BonusBlockView()
    }
}
