import SwiftUI

struct CertificateCardView: View {
    let certificate: Certificate
    let isOwned: Bool
    @StateObject private var imageCache = ImageCache() // ✅ Локальный кэш для изображений
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        VStack {
            if let imageUrl = certificate.imageUrl {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(20)
                        .padding()
                } else {
                    ProgressView()
                        .frame(height: 200)
                        .onAppear {
                            imageCache.loadImage(from: imageUrl) { image in
                                loadedImage = image
                            }
                        }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .foregroundColor(.gray)
                    .cornerRadius(20)
                    .padding()
            }

            Text("Сертификат № \(certificate.number)")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)

            Text("Баланс: \(certificate.balance) руб.")
                .font(.headline)
                .foregroundColor(.green)

            if !isOwned, let buyUrl = certificate.buyUrl, let url = URL(string: buyUrl) {
                Button(action: {
                    UIApplication.shared.open(url)
                }) {
                    Text("Купить")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct CertificateCardView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateCardView(
            certificate: Certificate(
                id: 409726,
                number: "888",
                balance: 9000,
                defaultBalance: 9000,
                typeID: 27841,
                statusID: 2,
                createdDate: Date(),
                expirationDate: nil,
                imageUrl: "https://24balance.hb.bizmrg.com/certificates/1000.png",
                buyUrl: "https://o677.yclients.com/loyalty/certificate/163597",
                type: CertificateType(title: "Массаж"),
                status: CertificateStatus(name: "Активен")
            ),
            isOwned: false
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
