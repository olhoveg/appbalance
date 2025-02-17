import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()
    @State private var activeIndex = 0  // 🔹 Для отслеживания текущей страницы

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ✅ Купленные сертификаты с пагинатором
                if !viewModel.ownedCertificates.isEmpty {
                    TabView(selection: $activeIndex) {
                        ForEach(viewModel.ownedCertificates.indices, id: \.self) { index in
                            CertificateCardView(certificate: viewModel.ownedCertificates[index], isOwned: true)
                                .padding(.horizontal)
                                .tag(index) // 🔹 Устанавливаем теги для отслеживания
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 🔹 Скрываем стандартные точки
                    .frame(height: 350)

                    // ✅ Пагинатор под картой
                    PaginationView(dots: viewModel.ownedCertificates.count, activeIndex: activeIndex)
                }

                // ✅ Доступные для покупки сертификаты
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
            viewModel.fetchCertificates()
        }
        .refreshable {
            viewModel.fetchCertificates()
        }
    }
}


