//CertificatesView.swift

import SwiftUI

struct CertificatesView: View {
    @StateObject private var viewModel = CertificateViewModel()
    @State private var activeIndex = 0  // Для отслеживания текущей страницы

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Блок купленных сертификатов или сообщение "Нет сертификатов"
                if viewModel.ownedCertificates.isEmpty {
                    Text("Нет сертификатов")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                } else {
                    TabView(selection: $activeIndex) {
                        ForEach(viewModel.ownedCertificates.indices, id: \.self) { index in
                            CertificateCardView(certificate: viewModel.ownedCertificates[index], isOwned: true)
                                .padding(.horizontal)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 350)
                    
                    // Пагинатор под картой
                    PaginationView(dots: viewModel.ownedCertificates.count, activeIndex: activeIndex)
                }
                
                // Блок доступных сертификатов для покупки
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
