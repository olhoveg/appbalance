import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Модель данных

struct LoyaltyCertificate: Identifiable, Codable, Equatable {
    let id: Int
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
    @Published var hasLoadedOnce = false
    
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
        URLSession.shared.dataTask(with: request) { data, _, error in
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
                    self.hasLoadedOnce = true
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
    @State private var loadedImage: UIImage? = nil
    @State private var isImageLoaded: Bool = false
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var scaleFactor: CGFloat {
        let baseWidth: CGFloat = 375 // Стандартный размер экрана iPhone 11, 12, 13
        return max(0.85, min(screenWidth / baseWidth, 1.2)) // Диапазон масштабирования 0.85 - 1.2
    }
    
    private var placeholderURL: URL? {
        let bg = colorScheme == .dark ? "1f1f1f" : "f2f2f7"
        let fg = "ffffff"
        let urlString = "https://via.placeholder.com/200x150.png?text=Сертификат&bg=\(bg)&fg=\(fg)"
        return URL(string: urlString)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width * 1, 400) // Максимальная ширина 400px на больших экранах
            let cardHeight = cardWidth * 0.4
            
            HStack(spacing: 12 * scaleFactor) {
                ZStack {
                    Color.gray.opacity(0.15)

                    if let url = certificateImageURL ?? placeholderURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .opacity(isImageLoaded ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.35), value: isImageLoaded)
                                    .onAppear {
                                        isImageLoaded = true
                                    }
                            case .failure:
                                Color.gray.opacity(0.15)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .frame(width: 140 * scaleFactor, height: 90 * scaleFactor)
                .cornerRadius(12 * scaleFactor)
                .clipped()
                
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    Text("Сертификат")
                        .font(.system(size: 18 * scaleFactor, weight: .bold))
                    Text("Номер: \(certificate.number)")
                        .font(.system(size: 14 * scaleFactor))
                    Text("Баланс: \(Int(certificate.balance)) ₽")
                        .font(.system(size: 14 * scaleFactor))
                        .frame(maxWidth: 150, alignment: .leading) // задаём максимальную ширину
                }
                .padding(.trailing, 12 * scaleFactor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
            )
            .frame(width: cardWidth, height: cardHeight)
            .onAppear(perform: fetchCertificateImage)
        }
        .frame(height: 160) // Фиксируем высоту контейнера, чтобы карточки не сжимались
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

// MARK: - Основной View с вертикальным refreshable

struct LoyaltyCertificateMainView: View {
    @ObservedObject var viewModel: LoyaltyCertificateViewModel
    @AppStorage("userPhone") private var userPhone: String = ""
    @State private var isInitialLoadCompleted = false
    
    var body: some View {
        ScrollView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && isInitialLoadCompleted {
                    ProgressView("Загрузка сертификатов...")
                } else if !viewModel.isLoading && isInitialLoadCompleted && viewModel.certificates.isEmpty {
                    if userPhone.isEmpty {
                        Text("Авторизуйтесь, чтобы увидеть сертификаты")
                            .foregroundColor(.secondary)
                    } else {
                        Text("У вас нет активных сертификатов")
                            .foregroundColor(.secondary)
                    }
                
                } else {
                    // Горизонтальный скролл с карточками
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.certificates) { certificate in
                                LoyaltyCertificateCardView(certificate: certificate)
                                    .frame(width: min(UIScreen.main.bounds.width * 0.9, 400)) // ✅ Ограничиваем максимальную ширину
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            if !userPhone.isEmpty {
                viewModel.fetchCertificates(phone: userPhone)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    isInitialLoadCompleted = true
                }
            }
        }
        .onAppear {
            if !userPhone.isEmpty && !viewModel.hasLoadedOnce {
                viewModel.fetchCertificates(phone: userPhone)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    isInitialLoadCompleted = true
                }
            } else if viewModel.hasLoadedOnce {
                isInitialLoadCompleted = true
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
