import SwiftUI
import Firebase
import FirebaseDatabase

class CertificateViewModel: ObservableObject {
    @Published var ownedCertificates: [Certificate] = [] // Сертификаты клиента
    @Published var availableCertificates: [Certificate] = [] // Доступные сертификаты
    @Published var isLoading: Bool = false

    private let API_URL = "https://api.yclients.com/api/v1"
    private let API_KEY = "88fnh8jbmt44er5y28nj"
    private let USER_KEY = "9d241fb00061c17a5e2e76a23b214b20"
    
    private let databaseRef = Database.database().reference()

    func fetchCertificates() {
        guard let phoneNumber = getUserPhoneNumber() else {
            print("❌ Ошибка: Номер телефона не найден в профиле")
            return
        }

        fetchOwnedCertificates(for: phoneNumber)
        fetchAvailableCertificates()
    }

    // 🚀 **Загрузка сертификатов клиента**
    private func fetchOwnedCertificates(for phoneNumber: String) {
        guard let url = URL(string: "\(API_URL)/loyalty/certificates/?company_id=433675&phone=\(phoneNumber)") else {
            print("Ошибка: Неверный URL")
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
                return
            }

            guard let data = data else {
                print("Ошибка: пустой ответ от сервера")
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedResponse: APIResponse = try decoder.decode(APIResponse.self, from: data)

                DispatchQueue.main.async {
                    self.ownedCertificates = decodedResponse.data
                    self.fetchCertificateDetails(for: self.ownedCertificates) // ✅ Загружаем фото для купленных сертификатов
                }
            } catch {
                print("Ошибка декодирования JSON: \(error.localizedDescription)")
            }
        }.resume()
    }

    // 🚀 **Загрузка доступных сертификатов из Firebase**
    private func fetchAvailableCertificates() {
        databaseRef.child("certificate_images").observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? [String: [String: Any]] {
                DispatchQueue.main.async {
                    self.availableCertificates = data.map { (key, value) in
                        Certificate(
                            id: Int.random(in: 1000...9999),
                            number: key,
                            balance: value["price"] as? Int ?? 0,
                            defaultBalance: nil,
                            typeID: nil,
                            statusID: nil,
                            createdDate: nil,
                            expirationDate: nil,
                            imageUrl: value["image_url"] as? String,
                            buyUrl: value["buyUrl"] as? String,
                            type: CertificateType(title: key),
                            status: nil
                        )
                    }.sorted { $0.balance < $1.balance }
                }
            } else {
                print("⚠️ Доступные сертификаты не найдены в Firebase")
            }
        }
    }

    // 🚀 **Загрузка изображений и ссылок на покупку**
    private func fetchCertificateDetails(for certificates: [Certificate]) {
        for index in certificates.indices {
            let certTitle = certificates[index].type?.title ?? ""

            guard !certTitle.isEmpty else {
                print("❌ Ошибка: У сертификата нет заголовка (title)")
                continue
            }

            let certRef = databaseRef.child("certificate_images").child(certTitle)
            
            certRef.observeSingleEvent(of: .value) { snapshot in
                if let data = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        self.ownedCertificates[index].imageUrl = data["image_url"] as? String
                        self.ownedCertificates[index].buyUrl = data["buyUrl"] as? String
                        print("✅ Фото загружено для \(certTitle)")
                    }
                } else {
                    print("⚠️ Фото не найдено в Firebase для \(certTitle)")
                }
            }
        }
    }



    private func getUserPhoneNumber() -> String? {
        return UserDefaults.standard.string(forKey: "userPhone")
    }
}
