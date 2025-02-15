import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if viewModel.certificates.isEmpty {
                Text("У вас пока нет сертификатов")
                    .foregroundColor(.gray)
            } else {
                TabView {
                    ForEach(viewModel.certificates) { cert in
                        CertificateCardView(certificate: cert)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            }
        }
        .onAppear {
            viewModel.fetchCertificates()
        }
        .refreshable {
            viewModel.fetchCertificates()
        }
    }
}
