import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()
    @State private var activeIndex = 0  // Для отслеживания текущей страницы
    @State private var hasLoaded = false // Флаг: данные загружены
    @State private var isInitialLoadCompleted = false

    // Вычисляемое свойство для количества точек в пагинаторе
    private var dotCount: Int {
        if !hasLoaded || viewModel.isLoading {
            return 3
        } else {
            return viewModel.ownedCertificates.count
        }
    }
    
    private func getUserPhoneNumber() -> String? {
        UserDefaults.standard.string(forKey: "userPhone")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isInitialLoadCompleted {
                    if let phone = getUserPhoneNumber(), !phone.isEmpty {
                        // Показываем skeleton или карточки только во время загрузки или при наличии сертификатов
                        if !hasLoaded || viewModel.isLoading || !viewModel.ownedCertificates.isEmpty {
                            ZStack {
                                Color.clear.frame(height: 380)
                                if !hasLoaded || viewModel.isLoading {
                                    // skeleton
                                    TabView {
                                        ForEach(0..<3, id: \.self) { index in
                                            SkeletonCertificateCardView()
                                                .padding(.horizontal)
                                                .tag(index)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 380)
                                } else {
                                    // реальные карточки
                                    TabView(selection: $activeIndex) {
                                        ForEach(viewModel.ownedCertificates.indices, id: \.self) { index in
                                            CertificateCardContainerView(
                                                certificate: viewModel.ownedCertificates[index],
                                                isOwned: true,
                                                isLoading: viewModel.isLoading
                                            )
                                            .padding(.horizontal)
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 380)
                                }
                            }
                        }
                        // Пагинатор для купленных сертификатов
                        if !hasLoaded {
                            PaginationView1(dots: 3, activeIndex: activeIndex)
                        } else if !viewModel.ownedCertificates.isEmpty {
                            PaginationView1(dots: viewModel.ownedCertificates.count, activeIndex: activeIndex)
                        }
                        
                        // Если данные загружены, но сертификатов нет, выводим сообщение
                        if hasLoaded && viewModel.ownedCertificates.isEmpty {
                            Text("У вас нет сертификатов")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.top, 0)    // Убрали большой отступ сверху
                                .padding(.bottom, 16)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        // Если номер телефона не найден – сразу показываем сообщение без пустого пространства
                        Text("Сертификаты недоступны. Пожалуйста, авторизуйтесь.")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    // Секция доступных сертификатов для покупки
                    if !viewModel.availableCertificates.isEmpty {
                        Text("Доступные сертификаты")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.availableCertificates) { cert in
                                CertificateCardView(certificate: cert, isOwned: false)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.fetchCertificates {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    hasLoaded = true
                    isInitialLoadCompleted = true
                }
            }
        }
        .refreshable {
            viewModel.fetchCertificates {
                hasLoaded = true
                isInitialLoadCompleted = true
            }
        }
    }
}

// Контейнер для плавного перехода между skeleton‑версией и реальной карточкой
struct CertificateCardContainerView: View {
    let certificate: Certificate
    let isOwned: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            SkeletonCertificateCardView()
                .opacity(isLoading ? 1 : 0)
            CertificateCardView(certificate: certificate, isOwned: isOwned)
                .opacity(isLoading ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// Простой пагинатор
struct PaginationView1: View {
    let dots: Int
    let activeIndex: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dots, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 10)
    }
}

struct CertificatesView_Previews: PreviewProvider {
    static var previews: some View {
        CertificatesView()
            .environmentObject(ImageCache.shared)
    }
}
