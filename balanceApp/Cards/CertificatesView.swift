import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ✅ Купленные сертификаты (без кнопки "Купить")
                if !viewModel.ownedCertificates.isEmpty {
                    Text("Ваши сертификаты")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 10)

                    TabView {
                        ForEach(viewModel.ownedCertificates) { cert in
                            CertificateCardView(certificate: cert, isOwned: true) // ✅ Передаём isOwned: true
                                .padding(.horizontal)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 350)
                }

                // ✅ Доступные для покупки сертификаты (с кнопкой "Купить")
                if !viewModel.availableCertificates.isEmpty {
                    Text("Доступные сертификаты")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    VStack(spacing: 15) {
                        ForEach(viewModel.availableCertificates) { cert in
                            CertificateCardView(certificate: cert, isOwned: false) // ✅ Передаём isOwned: false
                                .padding(.horizontal)
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
