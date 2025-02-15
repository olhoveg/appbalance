import SwiftUI

struct CertificateCardView: View {
    let certificate: Certificate
    let isOwned: Bool
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Изображение сертификата с номером (для купленных)
            ZStack(alignment: .topTrailing) {
                if let imageUrl = certificate.imageUrl {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
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
                }
                
                // Номер сертификата (только для купленных)
                if isOwned {
                    Text("№ \(certificate.number)")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding([.top, .trailing], 10)
                }
            }
            
            // Информация под изображением
            VStack(alignment: .leading, spacing: 4) {
                if isOwned {
                    if let purchaseDate = certificate.createdDate {
                        Text("Дата покупки: \(formattedDate(purchaseDate))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    if let expirationDate = certificate.expirationDate {
                        Text("Срок действия: \(formattedDate(expirationDate))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Срок действия: Бессрочный")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Баланс: \(certificate.balance) руб.")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if let buyUrl = certificate.buyUrl, let url = URL(string: buyUrl) {
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
                    }
                }
            }
            .padding([.leading, .trailing, .bottom])
        }
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU") // ✅ Устанавливаем русский язык
        formatter.dateFormat = "d MMMM yyyy" // ✅ Формат: 1 января 2025
        return formatter.string(from: date)
    }

}

struct CertificateCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Пример купленного сертификата
            CertificateCardView(
                certificate: Certificate(
                    id: 409726,
                    number: "888",
                    balance: 9000,
                    defaultBalance: 9000,
                    typeID: 27841,
                    statusID: 2,
                    createdDate: Date(), // Дата покупки
                    expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
                    imageUrl: "https://24balance.hb.bizmrg.com/certificates/1000.png",
                    buyUrl: nil,
                    type: CertificateType(title: "Массаж"),
                    status: CertificateStatus(name: "Активен")
                ),
                isOwned: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
            
            // Пример сертификата, доступного для покупки
            CertificateCardView(
                certificate: Certificate(
                    id: 1234,
                    number: "Test",
                    balance: 1000,
                    defaultBalance: nil,
                    typeID: nil,
                    statusID: nil,
                    createdDate: nil,
                    expirationDate: nil,
                    imageUrl: "https://24balance.hb.bizmrg.com/certificates/1000.png",
                    buyUrl: "https://o677.yclients.com/loyalty/certificate/163597",
                    type: CertificateType(title: "Сертификат 1000"),
                    status: nil
                ),
                isOwned: false
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
