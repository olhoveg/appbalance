import SwiftUI
import Foundation

struct AbonementDetailView: View {
    @State var abonement: Abonement
    @State private var isLoading: Bool = false

    var body: some View {
        List {
            Section(header: Text("Абонемент")) {
                Text("№ \(abonement.number)")
                Text("ID: \(abonement.id)")
            }
            Section(header: Text("История")) {
                let tx = (abonement.transactions ?? [])
                if !tx.isEmpty {
                    ForEach(tx.indices, id: \.self) { i in
                        let t = tx[i]
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Использование абонемента")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text("визит #\(t.visitId)")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                } else {
                    Text("Нет использований по абонементу")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            fetchTransactions()
        }
    }

    // Stub; replace with your real implementation if it exists elsewhere in your project
    private func fetchVisitDetailsForTransactions() {
        // no-op for now
    }

    private func fetchTransactions() {
        let chainId = "415038"

        print("\n==============================")
        print("🔎 fetchTransactions() start")
        print("Abonement id=\(self.abonement.id), number=\(self.abonement.number)")
        print("createdDate=\(self.abonement.createdDate)")
        if let exp = self.abonement.expirationDate {
            print("expirationDate=\(exp)")
        } else {
            print("expirationDate=nil (бессрочный или не задан)")
        }

        // Диапазон дат: с даты покупки абонемента до сегодняшнего дня
        let dfDateParam = DateFormatter()
        dfDateParam.dateFormat = "yyyy-MM-dd"

        let startDate = self.abonement.createdDate
        let endDate = Date()

        let createdAfter = dfDateParam.string(from: startDate)
        let createdBefore = dfDateParam.string(from: endDate)

        // types[]=9 — использование абонемента, types[]=10 — перерасчет по абонементу (для диагностики)
        let urlString = "https://api.yclients.com/api/v1/chain/\(chainId)/loyalty/transactions?created_after=\(createdAfter)&created_before=\(createdBefore)&types[]=9&types[]=10&count=100&page=1"

        print("Request URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for loyalty transactions")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        // В лог токен полностью не выводим, чтобы не светить
        let authHeader = "Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        print("Headers: Accept=application/vnd.yclients.v2+json, Content-Type=application/json, Authorization=<hidden>")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error for abonement \(self.abonement.id): \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP Status for abonement \(self.abonement.id): \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received for abonement \(self.abonement.number)")
                return
            }

            print("📦 Response bytes: \(data.count)")

            // Сырой ответ для отладки (можно закомментировать, если шумно)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw transactions JSON for abonement \(self.abonement.number):\n\(jsonString)")
            }

            do {
                let decoder = JSONDecoder()
                let dfISO = DateFormatter()
                dfISO.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                decoder.dateDecodingStrategy = .formatted(dfISO)

                let response = try decoder.decode(TransactionAPIResponse.self, from: data)
                let all = response.data
                print("✅ Decoded transactions count: \(all.count)")

                // Диагностика: распределение по typeId
                let typeHistogram = Dictionary(grouping: all, by: { $0.typeId }).mapValues { $0.count }
                print("📊 typeId histogram: \(typeHistogram)")

                // Диагностика: первые 10 значений abonementId
                let sample = all.prefix(10)
                for (idx, tx) in sample.enumerated() {
                    print("🔹 tx[#\(idx)] id=\(tx.id) typeId=\(tx.typeId) visitId=\(String(describing: tx.visitId)) abonementId=\(String(describing: tx.abonementId))")
                }

                // Фильтруем по текущему абонементу
                let filtered = all.filter { $0.abonementId == self.abonement.id }
                print("🧮 Filtered by abonementId=\(self.abonement.id): \(filtered.count)")

                // Дополнительно оставляем только операции использования абонемента (typeId == 9)
                let filtered9 = filtered.filter { $0.typeId == 9 }
                print("🎯 After typeId==9 filter: \(filtered9.count)")

                DispatchQueue.main.async {
                    self.abonement.transactions = filtered9
                    self.fetchVisitDetailsForTransactions()
                }
            } catch {
                print("❌ Transactions decode error for abonement \(self.abonement.number): \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❗️ Decode failed on JSON:\n\(jsonString)")
                }
            }
        }.resume()
    }
}
