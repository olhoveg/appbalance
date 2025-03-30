import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()
    @State private var activeIndex = 0  // Для отслеживания текущей страницы
    @State private var hasLoaded = false // Флаг: данные загружены

    // Вычисляемое свойство для количества точек в пагинаторе
    private var dotCount: Int {
        if !hasLoaded || viewModel.isLoading {
            return 3
        } else {
            return viewModel.ownedCertificates.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Фиксированная область для отображения купленных сертификатов
                ZStack {
                    Color.clear.frame(height: 350)
                    
                    if !hasLoaded || viewModel.isLoading {
                        // Пока данные загружаются – показываем TabView с skeleton‑версией
                        TabView {
                            ForEach(0..<3, id: \.self) { index in
                                SkeletonCertificateCardView()
                                    .padding(.horizontal)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 350)
                    } else if !viewModel.ownedCertificates.isEmpty {
                        // Если данные загружены и сертификаты есть – показываем реальные карточки
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
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // <-- Ставим .never
                        .frame(height: 350)
                    } else {
                        // Если загрузка завершена и массив пуст – оставляем область пустой
                        Color.clear.frame(height: 350)
                    }
                }
                
                // Единственный пагинатор, который всегда отображается под фиксированной областью
                PaginationView1(dots: dotCount, activeIndex: activeIndex)
                
                // Если загрузка завершена, но купленных сертификатов нет – выводим сообщение
                if hasLoaded && viewModel.ownedCertificates.isEmpty {
                    Text("Нет сертификатов")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
                
                // Секция доступных сертификатов для покупки
                if !viewModel.availableCertificates.isEmpty {
                    Text("Доступные сертификаты")
                        .font(.title)
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
            .padding()
        }
        .onAppear {
            viewModel.fetchCertificates {
                hasLoaded = true
            }
        }
        .refreshable {
            viewModel.fetchCertificates {
                hasLoaded = true
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
