import SwiftUI

// MARK: - Модели данных
struct DepositResponse: Codable {
    let data: [DepositItem]
}

struct DepositItem: Codable {
    let deposit: Deposit
}

struct Deposit: Codable {
    let balance: Int
}

// MARK: - ViewModel
class BalanceBlockViewModel: ObservableObject {
    @AppStorage("userPhone") private var storedPhone: String?

    @Published var balance: Int = 0
    @Published var balanceLoaded: Bool = false

    var phone: String? {
        storedPhone
    }

    init() {
        fetchData()
    }

    func fetchData() {
        guard let phone = storedPhone else {
            balance = 0
            balanceLoaded = false
            return
        }

        let companyId = "415038"
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"

        Task {
            do {
                let total = try await fetchBalance(
                    chainId: companyId,
                    phone: phone,
                    accessToken: accessToken,
                    accessUserToken: accessUserToken
                )
                await MainActor.run {
                    self.balance = total
                    self.balanceLoaded = true
                }
            } catch {
                await MainActor.run {
                    self.balance = 0
                    self.balanceLoaded = false
                }
                print("Ошибка при получении баланса: \(error.localizedDescription)")
            }
        }
    }

    private func fetchBalance(chainId: String, phone: String, accessToken: String, accessUserToken: String) async throws -> Int {
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

// MARK: - Основное View
struct BalanceBlockView: View {
    @StateObject private var viewModel = BalanceBlockViewModel()

    var body: some View {
        Group {
            if viewModel.phone == nil {
                Text("Авторизуйтесь, чтобы посмотреть баланс")
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            } else if viewModel.balanceLoaded {
                HStack(alignment: .center) {
                    Image(systemName: "creditcard.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 8)
                    Text("Личный счет: \(viewModel.balance) ₽")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .padding(.top, 10)
                .padding(.horizontal, 10)
            } else {
                ProgressView("Загрузка баланса...")
                    .padding(.top, 10)
            }
        }
        .onAppear {
            viewModel.fetchData()
        }
    }
}

// MARK: - Превью
struct BalanceBlockView_Previews: PreviewProvider {
    static var previews: some View {
        BalanceBlockView()
            .previewLayout(.sizeThatFits)
    }
}
