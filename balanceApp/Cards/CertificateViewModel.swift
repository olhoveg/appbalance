import SwiftUI
import Firebase
import FirebaseDatabase

class CertificateViewModel: ObservableObject {
    @Published var certificates: [Certificate] = []
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
                    self.certificates = decodedResponse.data
                    self.fetchCertificateImages()
                }
            } catch {
                print("Ошибка декодирования JSON: \(error.localizedDescription)")
            }
        }.resume()
    }

    // 🚀 Получаем номер телефона из профиля (UserDefaults)
    private func getUserPhoneNumber() -> String? {
        return UserDefaults.standard.string(forKey: "userPhone")
    }

    private func fetchCertificateImages() {
        for index in certificates.indices {
            let certTitle = certificates[index].type?.title ?? ""

            guard !certTitle.isEmpty else {
                print("❌ Ошибка: У сертификата нет заголовка (title)")
                continue
            }

            let certRef = databaseRef.child("certificate_images").child(certTitle)
            
            certRef.observeSingleEvent(of: .value) { snapshot in
                if let data = snapshot.value as? [String: Any], let imageUrl = data["image_url"] as? String {
                    DispatchQueue.main.async {
                        self.certificates[index].imageUrl = imageUrl
                        print("✅ Изображение загружено для \(certTitle): \(imageUrl)")
                    }
                } else {
                    print("⚠️ Изображение не найдено в Realtime Database для \(certTitle)")
                }
            }
        }
    }
}
