import SwiftUI
import FirebaseDatabase

private let API_KEY = "88fnh8jbmt44er5y28nj"

struct BonusBlockView: View {
    @State private var bonusCards: [BonusCard] = []
    @State private var activeIndex: Int = 0
    @State private var isLoading = true        // стартуем в режиме загрузки (скелетон)
    @AppStorage("userPhone") private var phoneNumber: String = ""
    @State private var showingProgramDetail = false
    @State private var selectedProgram: LoyaltyProgram?
    
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
                                    .onAppear {
                                        print("🎯 Showing 'no cards' message")
                                        print("🎯 Phone: \(phoneNumber)")
                                        print("🎯 Loading: \(isLoading)")
                                        print("🎯 Cards count: \(bonusCards.count)")
                                    }
                            } else {
                                VStack {
                                    ProgressView("Загрузка бонусных карт...")
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Получаем данные с сервера...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                                .onAppear {
                                    print("🎯 Showing loading indicator")
                                }
                            }
                        } else {
                            TabView(selection: $activeIndex) {
                                ForEach(bonusCards) { card in
                                    BonusBlockCardView(bonusCard: card)
                                        .padding(.horizontal, 20)
                                        .tag(card.id)
                                        .onAppear {
                                            print("🎯 Displaying card: \(card.number) with balance: \(card.balance)")
                                        }
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 300)
                            .animation(.easeInOut, value: activeIndex)
                            .onAppear {
                                print("🎯 Showing TabView with \(bonusCards.count) cards")
                            }
                            
                            // Программы лояльности для активной карты
                            if !bonusCards.isEmpty {
                                let currentCardIndex = bonusCards.firstIndex { $0.id == activeIndex } ?? 0
                                let currentCard = bonusCards[currentCardIndex]
                                if let programs = currentCard.programs, !programs.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Заголовок секции
                                        HStack {
                                            Text("Программы лояльности")
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text("\(programs.count)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange)
                                                .clipShape(Capsule())
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.top, 10)
                                        
                                        // Список программ
                                        LazyVStack(spacing: 12) {
                                            ForEach(programs) { program in
                                                LoyaltyProgramCard(program: program)
                                                    .onTapGesture {
                                                        selectedProgram = program
                                                        showingProgramDetail = true
                                                    }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .animation(.easeInOut, value: activeIndex)
                                }
                            }
                        }
                    } else {
                        // Нет номера телефона
                        Text("Бонусные карты недоступны. Пожалуйста, авторизуйтесь.")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                            .multilineTextAlignment(.center)
                            .onAppear {
                                print("🎯 No phone number available")
                            }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            print("🎯 BonusBlockView appeared")
            print("📱 Current phone number: '\(phoneNumber)'")
            if !phoneNumber.isEmpty {
                print("📱 Phone number available, fetching cards...")
                fetchBonusCards()
            } else {
                print("❌ No user phone found")
            }
        }
        .refreshable {
            fetchBonusCards()
        }
        .sheet(isPresented: $showingProgramDetail) {
            if let program = selectedProgram {
                LoyaltyProgramDetailView(program: program)
            }
        }
    }
    
    private func fetchBonusCards() {
        guard !phoneNumber.isEmpty else { 
            print("❌ Phone number is empty, cannot fetch bonus cards")
            return 
        }
        
        print("🔄 Starting to fetch bonus cards for phone: \(phoneNumber)")
        
        // Устанавливаем флаг загрузки, чтобы сразу показать скелетон
        DispatchQueue.main.async {
            isLoading = true
        }
        
        let groupId = "415038"
        let companyId = "433675"
        let urlString = "https://api.yclients.com/api/v1/loyalty/cards/\(phoneNumber)/\(groupId)/\(companyId)"
        
        print("🌐 Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            DispatchQueue.main.async { isLoading = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(API_KEY), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        print("📤 Sending request to YCLIENTS API...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("❌ Ошибка при получении бонусных карт: \(error.localizedDescription)")
                    isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP Response Status: \(httpResponse.statusCode)")
                print("📥 HTTP Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                print("❌ No data received from API")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            print("📄 Raw response data length: \(data.count) bytes")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw response JSON: \(jsonString)")
            }
            do {
                print("🔄 Attempting to decode JSON response...")
                let decoder = JSONDecoder()
                let response = try decoder.decode(BonusAPIResponse.self, from: data)
                
                print("✅ Successfully decoded response")
                print("✅ Success flag: \(response.success)")
                print("✅ Number of bonus cards: \(response.data.count)")
                
                for (index, card) in response.data.enumerated() {
                    print("💳 Card \(index + 1):")
                    print("   - ID: \(card.id)")
                    print("   - Number: \(card.number)")
                    print("   - Balance: \(card.balance)")
                    print("   - Type: \(card.type.title)")
                    if let transactions = card.transactions {
                        print("   - Transactions: \(transactions.count)")
                    } else {
                        print("   - Transactions: nil")
                    }
                }
                
                DispatchQueue.main.async {
                    bonusCards = response.data
                    isLoading = false
                    print("🎯 UI updated with \(response.data.count) bonus cards")
                    
                    // Устанавливаем активный индекс на первую карту
                    if let firstCard = response.data.first {
                        activeIndex = firstCard.id
                    }
                    
                    // Загружаем транзакции для каждой карты
                    for card in response.data {
                        fetchTransactions(for: card)
                    }
                }
            } catch {
                print("❌ Ошибка декодирования бонусных карт: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("❌ Decoding error details: \(decodingError)")
                }
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }
    
    private func fetchTransactions(for card: BonusCard) {
        print("🔄 Fetching transactions for card ID: \(card.id)")
        
        // Попробуем правильный API endpoint для транзакций
        let urlString = "https://api.yclients.com/api/v1/loyalty/cards/\(card.id)/operations"
        print("🌐 Transactions URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid transactions URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(API_KEY), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Transactions network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Transactions HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No transactions data received")
                return
            }
            
            print("📄 Transactions data length: \(data.count) bytes")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Transactions JSON: \(jsonString)")
                
                // Пытаемся декодировать ответ
                do {
                    let decoder = JSONDecoder()
                    if let jsonData = jsonString.data(using: .utf8) {
                        let response = try decoder.decode(BonusAPIResponse.self, from: jsonData)
                        print("✅ Transactions decoded successfully")
                        print("✅ Transactions count: \(response.data.count)")
                    }
                } catch {
                    print("❌ Transactions decode error: \(error)")
                }
            }
            
            print("✅ Transactions request completed for card \(card.id)")
            
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




