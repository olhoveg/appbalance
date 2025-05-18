import SwiftUI
import Firebase
import FirebaseDatabase
import Foundation

// Расширение для преобразования строки в дату
extension String {
    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // Формат даты из Firebase
        return formatter.date(from: self)
    }
}

class CertificateViewModel: ObservableObject {
    @Published var ownedCertificates: [Certificate] = []      // Купленные сертификаты
    @Published var availableCertificates: [Certificate] = []  // Доступные для покупки
    @Published var isLoading: Bool = false
    @Published var isAuthorized: Bool = false  // Флаг авторизации пользователя

    private let API_URL = "https://api.yclients.com/api/v1"
    private let API_KEY = "88fnh8jbmt44er5y28nj"
    private let USER_KEY = "9d241fb00061c17a5e2e76a23b214b20"
    
    private let databaseRef = Database.database().reference()

    func fetchCertificates(completion: @escaping () -> Void = {}) {
        // Всегда загружаем доступные сертификаты
        fetchAvailableCertificates()
        
        guard let phoneNumber = getUserPhoneNumber() else {
            print("❌ Ошибка: Номер телефона не найден")
            self.isAuthorized = false
            completion()
            return
        }
        
        self.isAuthorized = true
        fetchOwnedCertificates(for: phoneNumber) {
            completion()
        }
    }

    private func fetchOwnedCertificates(for phoneNumber: String, completion: @escaping () -> Void = {}) {
        guard let url = URL(string: "\(API_URL)/loyalty/certificates/?company_id=433675&phone=\(phoneNumber)") else {
            print("Ошибка: Неверный URL")
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(API_KEY), User \(USER_KEY)", forHTTPHeaderField: "Authorization")
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Ошибка загрузки сертификатов: \(error.localizedDescription)")
                completion()
                return
            }
            
            guard let data = data else {
                print("Ошибка: пустой ответ от сервера")
                completion()
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedResponse: APIResponse = try decoder.decode(APIResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.ownedCertificates = decodedResponse.data
                    self.fetchCertificateDetails(for: self.ownedCertificates)
                    completion()
                }
            } catch {
                print("Ошибка декодирования JSON: \(error.localizedDescription)")
                completion()
            }
        }.resume()
    }


    private func fetchAvailableCertificates() {
        databaseRef.child("certificate_images").observeSingleEvent(of: .value, with: { snapshot in
            print("Получен snapshot для availableCertificates: \(snapshot.value ?? "nil")")
            
            // Приводим snapshot.value к типу [String: Any]
            guard let data = snapshot.value as? [String: Any] else {
                print("⚠️ Доступные сертификаты не найдены в Firebase")
                return
            }
            
            var certs = [Certificate]()
            for (key, value) in data {
                if let dict = value as? [String: Any] {
                    let certificate = Certificate(
                        id: Int.random(in: 1000...9999),
                        number: key,
                        balance: dict["price"] as? Int ?? 0,
                        defaultBalance: nil,
                        typeID: nil,
                        statusID: nil,
                        createdDate: nil,
                        expirationDate: (dict["expirationDate"] as? String)?.toDate(),
                        imageUrl: dict["image_url"] as? String,
                        buyUrl: dict["buyUrl"] as? String,
                        expirationText: dict["expirationText"] as? String,
                        price: dict["price"] as? Int ?? 0,
                        type: CertificateType(title: key),
                        status: nil
                    )
                    certs.append(certificate)
                }
            }
            
            DispatchQueue.main.async {
                self.availableCertificates = certs.sorted { $0.balance < $1.balance }
            }
        })
    }

    private func fetchCertificateDetails(for certificates: [Certificate]) {
        for (index, cert) in certificates.enumerated() {
            let certTitle = cert.type?.title ?? ""
            guard !certTitle.isEmpty else { continue }
            
            let certRef = databaseRef.child("certificate_images").child(certTitle)
            certRef.observeSingleEvent(of: .value, with: { snapshot in
                if let data = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        self.ownedCertificates[index].imageUrl = data["image_url"] as? String
                        self.ownedCertificates[index].buyUrl = data["buyUrl"] as? String
                        if let expText = data["expirationText"] as? String {
                            self.ownedCertificates[index].expirationText = expText
                        }
                        if let expDateString = data["expirationDate"] as? String {
                            self.ownedCertificates[index].expirationDate = expDateString.toDate()
                        }
                    }
                }
            })
        }
    }

    private func getUserPhoneNumber() -> String? {
        // Здесь предполагается, что номер телефона сохраняется в UserDefaults
        UserDefaults.standard.string(forKey: "userPhone")
    }
}
