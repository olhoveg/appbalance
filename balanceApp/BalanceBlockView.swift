import SwiftUI

// Модели данных для декодирования JSON-ответа
struct DepositResponse: Codable {
    let data: [DepositItem]
}

struct DepositItem: Codable {
    let deposit: Deposit
}

struct Deposit: Codable {
    let balance: Int
}

// ViewModel для управления состоянием
class BalanceBlockViewModel: ObservableObject {
    @Published var phone: String? = nil
    @Published var balance: Int = 0
    @Published var balanceLoaded: Bool = false

    init() {
        loadPhone()
    }

    // Загрузка номера телефона из UserDefaults (аналог AsyncStorage)
    func loadPhone() {
        // Используем ключ "userPhone"
        self.phone = UserDefaults.standard.string(forKey: "userPhone")
        if phone != nil {
            fetchData()
        }
    }

    // Основной метод для получения данных
    func fetchData() {
        guard let phone = phone else { return }
        let companyId = "415038"
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        Task {
            do {
                let totalBalance = try await fetchBalance(chainId: companyId, phone: phone, accessToken: accessToken, accessUserToken: accessUserToken)
                // Обновляем UI на главном потоке
                await MainActor.run {
                    self.balance = totalBalance
                    self.balanceLoaded = true
                }
            } catch {
                print("Error fetching balance: \(error)")
            }
        }
    }

    // Функция для выполнения запроса и расчёта баланса
    func fetchBalance(chainId: String, phone: String, accessToken: String, accessUserToken: String) async throws -> Int {
        guard let url = URL(string: "https://api.yclients.com/api/v1/deposits/chain/\(chainId)/phone/\(phone)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decodedResponse = try JSONDecoder().decode(DepositResponse.self, from: data)
        let totalBalance = decodedResponse.data.reduce(0) { $0 + $1.deposit.balance }
        return totalBalance
    }
}

// SwiftUI View для отображения баланса
struct BalanceBlockView: View {
    @StateObject private var viewModel = BalanceBlockViewModel()

    var body: some View {
        Group {
            if viewModel.balanceLoaded {
                HStack(alignment: .center) {
                    Image(systemName: "creditcard.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 8)
                    Text("Личный счет: \(viewModel.balance) ₽")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.top, 10)
                .padding(.horizontal, 10)
            } else {
                // Здесь можно разместить индикатор загрузки
                EmptyView()
            }
        }
        .onAppear {
            // Можно вызвать обновление данных извне, если требуется
            viewModel.fetchData()
        }
    }
}

// Пример предварительного просмотра
struct BalanceBlockView_Previews: PreviewProvider {
    static var previews: some View {
        BalanceBlockView()
            .previewLayout(.sizeThatFits)
    }
}
