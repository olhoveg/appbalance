// AbonementViewModel.swift

import Foundation

class AbonementViewModel: ObservableObject {
    @Published var abonements: [Abonement] = []
    @Published var isLoading: Bool = false

    /// Загружает абонементы и после всего — вызывает completion (для установки hasLoaded)
    func fetchAbonements(completion: @escaping () -> Void) {
        guard let phone = UserDefaults.standard.string(forKey: "userPhone") else {
            // Нет телефона — сразу завершаем без данных
            DispatchQueue.main.async {
                self.abonements = []
                self.isLoading = false
                completion()
            }
            return
        }

        let urlString = "https://api.yclients.com/api/v1/loyalty/abonements/?company_id=433675&phone=\(phone)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.abonements = []
                self.isLoading = false
                completion()
            }
            return
        }

        // Запускаем загрузку
        self.isLoading = true
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            // Все завершающие изменения — в один главный поток
            DispatchQueue.main.async {
                defer {
                    // Обязательно снимаем индикатор загрузки и ставим флаг завершения
                    self.isLoading = false
                    completion()
                }
                guard error == nil, let data = data else {
                    // Что-то пошло не так — оставляем массив пустым
                    print("Ошибка загрузки абонементов: \(error?.localizedDescription ?? "no data")")
                    self.abonements = []
                    return
                }
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let resp = try decoder.decode(AbonementAPIResponse.self, from: data)
                    self.abonements = resp.data
                    self.abonements.forEach { print("Abonement loaded: \($0)") }
                    self.fetchTransactionsForAllAbonements()
                } catch {
                    print("Ошибка парсинга абонементов: \(error.localizedDescription)")
                    self.abonements = []
                }
            }
        }.resume()
    }
    
    private func fetchTransactionsForAllAbonements() {
        for abonement in abonements {
            fetchTransactions(for: abonement)
        }
    }

    private func fetchTransactions(for abonement: Abonement) {
        let chainId = "415038"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let createdBefore = dateFormatter.string(from: Date())
        let createdAfter = dateFormatter.string(from: Calendar.current.date(byAdding: .year, value: -1, to: Date())!)
        
        let urlString = "https://api.yclients.com/api/v1/chain/\(chainId)/loyalty/transactions?created_after=\(createdAfter)&created_before=\(createdBefore)&types[]=9"
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                return
            }

            do {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)

                let response = try decoder.decode(TransactionAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    if let index = self.abonements.firstIndex(where: { $0.id == abonement.id }) {
                        self.abonements[index].transactions = response.data.filter { $0.abonementId == abonement.id }
                        self.fetchVisitDetailsForTransactions(abonementIndex: index)
                    }
                }
            } catch {
                print("❌ Transactions decode error for abonement \(abonement.id): \(error)")
            }
        }.resume()
    }

    private func fetchVisitDetailsForTransactions(abonementIndex: Int) {
        guard let transactions = abonements[abonementIndex].transactions else { return }
        for (transactionIndex, transaction) in transactions.enumerated() {
            fetchVisitDetails(for: transaction.visitId) { visitDetails in
                DispatchQueue.main.async {
                    self.abonements[abonementIndex].transactions?[transactionIndex].visitDetails = visitDetails
                }
            }
        }
    }
    
    private func fetchVisitDetails(for visitId: Int, completion: @escaping (VisitDetails?) -> Void) {
        let urlString = "https://api.yclients.com/api/v1/visits/\(visitId)"
        print("Fetching visit details for visit ID: \(visitId)")
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw visit details JSON for visit \(visitId): \(jsonString)")
            }

            do {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)

                let visitResponse = try decoder.decode(AppVisitResponse.self, from: data)
                
                if let record = visitResponse.data?.records.first,
                   let service = record.services.first {
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    let startTime = dateFormatter.date(from: record.datetime) ?? Date()
                    let endTime = startTime.addingTimeInterval(TimeInterval(record.length))
                    
                    let visitDetails = VisitDetails(
                        serviceTitle: service.title,
                        specialistName: record.staff.name,
                        startTime: startTime,
                        endTime: endTime,
                        serviceCost: service.cost
                    )
                    completion(visitDetails)
                } else {
                    completion(nil)
                }
            } catch {
                print("❌ Visit decode error for visit \(visitId): \(error)")
                completion(nil)
            }
        }.resume()
    }
}
