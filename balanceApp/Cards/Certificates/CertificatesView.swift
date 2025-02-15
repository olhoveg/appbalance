import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ✅ Купленные сертификаты
                if !viewModel.ownedCertificates.isEmpty {
                    Text("Ваши сертификаты")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 10)

                    TabView {
                        ForEach(viewModel.ownedCertificates) { cert in
                            CertificateCardView(certificate: cert, isOwned: true)
                                .padding(.horizontal)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 350)
                }

                // ✅ Доступные для покупки сертификаты (исправлено наложение)
                if !viewModel.availableCertificates.isEmpty {
                    Text("Доступные сертификаты")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    LazyVStack(spacing: 15) { // ✅ Исправлено наложение
                        ForEach(viewModel.availableCertificates) { cert in
                            CertificateCardView(certificate: cert, isOwned: false)
                                .padding(.horizontal)
                                .padding(.vertical, 10) // ✅ Добавил отступы сверху и снизу
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
