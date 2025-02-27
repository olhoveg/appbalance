import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Модель данных

struct LoyaltyCertificate: Identifiable, Codable, Equatable {
    let id = UUID()
    let number: String
    let balance: Double
    let type: LoyaltyCertificateType
    
    struct LoyaltyCertificateType: Codable, Equatable {
        let title: String
    }
}

struct LoyaltyCertificateResponse: Codable {
    let data: [LoyaltyCertificate]
}

// MARK: - ViewModel

class LoyaltyCertificateViewModel: ObservableObject {
    @Published var certificates: [LoyaltyCertificate] = []
    @Published var isLoading = false
    
    private let apiURL = "https://api.yclients.com/api/v1/loyalty/certificates/"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let companyId = "433675"
    
    func fetchCertificates(phone: String) {
        guard !phone.isEmpty else {
            print("Номер телефона пустой")
            return
        }
        
        guard var urlComponents = URLComponents(string: apiURL) else { return }
        urlComponents.queryItems = [
            URLQueryItem(name: "company_id", value: companyId),
            URLQueryItem(name: "phone", value: phone)
        ]
        
        guard let url = urlComponents.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey), User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
            
            if let error = error {
                print("Ошибка при загрузке сертификатов: \(error)")
                return
            }
            
            guard let data = data else {
                print("Нет данных")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(LoyaltyCertificateResponse.self, from: data)
                DispatchQueue.main.async {
                    self.certificates = decodedResponse.data
                }
            } catch {
                print("Ошибка декодирования: \(error)")
            }
        }.resume()
    }
}

// MARK: - Карточка сертификата

struct LoyaltyCertificateCardView: View {
    var certificate: LoyaltyCertificate
    @Environment(\.colorScheme) private var colorScheme
    @State private var certificateImageURL: URL?
    
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "f2f2f7"
        let fg = "ffffff"
        let urlString = "https://via.placeholder.com/200x150.png?text=Сертификат&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: certificateImageURL ?? placeholderURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 150)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(.gray)
                @unknown default:
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 160, height: 100)
            .cornerRadius(12)
            .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Сертификат")
                    .font(.title2)
                    .bold()
                Text("Номер: \(certificate.number)")
                    .font(.headline)
                Text("Баланс: \(certificate.balance, specifier: "%.2f") ₽")
                    .font(.headline)
            }
            .padding(.trailing, 16)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
        )
        .frame(height: 140) // увеличенный блок сертификата
        .onAppear(perform: fetchCertificateImage)
    }
    
    private func fetchCertificateImage() {
        let ref = Database.database().reference(withPath: "certificate_images")
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let imagesDict = snapshot.value as? [String: Any] else { return }
            for (_, value) in imagesDict {
                if let imageInfo = value as? [String: Any],
                   let title = imageInfo["title"] as? String,
                   title == certificate.type.title,
                   let imageUrlString = imageInfo["image_url"] as? String,
                   let url = URL(string: imageUrlString) {
                    DispatchQueue.main.async {
                        certificateImageURL = url
                    }
                    return
                }
            }
        } withCancel: { error in
            print("Ошибка загрузки изображения: \(error.localizedDescription)")
        }
    }
}

// MARK: - Основной View с горизонтальным скроллом

struct LoyaltyCertificateMainView: View {
    @ObservedObject var viewModel: LoyaltyCertificateViewModel
    @AppStorage("userPhone") private var userPhone: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Загрузка сертификатов...")
            } else if viewModel.certificates.isEmpty {
                Text(userPhone.isEmpty ? "Номер клиента не найден" : "Сертификаты отсутствуют")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.certificates) { certificate in
                            LoyaltyCertificateCardView(certificate: certificate)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .onAppear {
            if !userPhone.isEmpty {
                viewModel.fetchCertificates(phone: userPhone)
            }
        }
    }
}

// MARK: - Превью

struct LoyaltyCertificateMainView_Previews: PreviewProvider {
    static var previews: some View {
        LoyaltyCertificateMainView(viewModel: LoyaltyCertificateViewModel())
            .preferredColorScheme(.light)
    }
}
