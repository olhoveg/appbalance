import SwiftUI

// MARK: - Модель данных

struct LoyaltyCertificate: Identifiable, Codable {
    let id = UUID()
    let number: String
    let balance: Double
    let type: LoyaltyCertificateType
    
    struct LoyaltyCertificateType: Codable {
        let title: String
    }
}

struct LoyaltyCertificateResponse: Codable {
    let data: [LoyaltyCertificate]
}

// MARK: - ViewModel для загрузки сертификатов

class LoyaltyCertificateViewModel: ObservableObject {
    @Published var certificates: [LoyaltyCertificate] = []
    @Published var isLoading = false
    
    private let apiURL = "https://api.yclients.com/api/v1/loyalty/certificates/"
    private let apiKey = "88fnh8jbmt44er5y28nj"
    private let companyId = "433675"
    
    func fetchCertificates(phone: String) {
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

// MARK: - Представление для карточки сертификата

struct LoyaltyCertificateCardView: View {
    var certificate: LoyaltyCertificate
    
    // Placeholder-изображение, можно заменить на логику загрузки изображения по certificate.type.title
    var imageURL: URL? {
        URL(string: "https://via.placeholder.com/300x150.png?text=Certificate")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                } else if phase.error != nil {
                    Color.red.frame(height: 150)
                } else {
                    Color.gray.frame(height: 150)
                }
            }
            .cornerRadius(10)
            
            Text("Сертификат")
                .font(.headline)
            
            Text("Номер карты: \(certificate.number)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Баланс: \(certificate.balance, specifier: "%.2f") ₽")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Основное представление с каруселью сертификатов

struct LoyaltyCertificateCarouselView: View {
    @StateObject private var viewModel = LoyaltyCertificateViewModel()
    
    // Номер телефона можно получать из UserDefaults или другого хранилища; здесь для примера задан статически
    @State private var phone: String = "1234567890"
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Загрузка сертификатов...")
                        .padding()
                } else {
                    if viewModel.certificates.isEmpty {
                        Text("Сертификаты отсутствуют")
                            .foregroundColor(.secondary)
                    } else {
                        // Используем TabView с PageTabViewStyle для имитации карусели с пагинацией
                        TabView {
                            ForEach(viewModel.certificates) { certificate in
                                LoyaltyCertificateCardView(certificate: certificate)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .frame(height: 300)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.fetchCertificates(phone: phone)
                }) {
                    Text("Обновить сертификаты")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Сертификаты")
            .onAppear {
                viewModel.fetchCertificates(phone: phone)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Превью

struct LoyaltyCertificateCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        LoyaltyCertificateCarouselView()
    }
}
