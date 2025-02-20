import SwiftUI

struct AbonementBlockView: View {
    @State private var abonements: [Abonement] = []
    @State private var activeIndex: Int = 0 // 🔹 Следит за текущей страницей
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !abonements.isEmpty {
                        // ✅ Таблица с абонементами
                        TabView(selection: $activeIndex) {
                            ForEach(abonements.indices, id: \.self) { index in
                                AbonementCardView(abonement: abonements[index], phoneNumber: getUserPhoneNumber() ?? "")
                                    .padding(.horizontal)
                                    .tag(index) // 🔹 Устанавливаем теги для отслеживания страницы
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 🔹 Скрываем стандартный индикатор
                        .frame(height: 400)

                        // ✅ Добавляем кастомный пагинатор
                        PaginationView(dots: abonements.count, activeIndex: activeIndex)
                    } else if isLoading {
                        ProgressView()
                    } else {
                        Text("Нет абонементов")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                    }

                    // ✅ Блок покупки абонементов
                    AbonementPurchaseListView()
                }
                .padding()
            }
            .onAppear {
                fetchAbonements()
            }
            .refreshable {
                fetchAbonements()
            }
        }
    }
    
    private func getUserPhoneNumber() -> String? {
        UserDefaults.standard.string(forKey: "userPhone")
    }
    
    private func fetchAbonements() {
        guard let phone = getUserPhoneNumber() else { return }
        isLoading = true
        let urlString = "https://api.yclients.com/api/v1/loyalty/abonements/?company_id=433675&phone=\(phone)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            if let error = error {
                print("Ошибка: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let response = try decoder.decode(AbonementAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    abonements = response.data
                }
            } catch {
                print("Ошибка декодирования: \(error.localizedDescription)")
            }
        }.resume()
    }
}


