import SwiftUI

struct CertificateCardView: View {
    let certificate: Certificate
    let isOwned: Bool
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        if isOwned {
            // ✅ Купленные сертификаты (фиксированная высота ~320)
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    certificateImageView()
                        .frame(height: 200) // Высота изображения
                        .cornerRadius(15)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        )

                    Text("№ \(certificate.number)")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let purchaseDate = certificate.createdDate {
                        Text("Дата покупки: \(formattedDate(purchaseDate))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    if let expirationDate = certificate.expirationDate {
                        Text("Срок действия: \(formattedDate(expirationDate))")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if let expText = certificate.expirationText {
                        Text("Срок действия: \(expText)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else {
                        Text("Срок действия: Бессрочный")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding([.leading, .trailing, .bottom])
            }
            .frame(maxWidth: .infinity) // Растягиваем на всю ширину
            .padding(.horizontal, 10) // Уменьшаем отступы для маленьких экранов
            .padding(.top, 10)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 5)
        } else {
            // ✅ Сертификаты, доступные к покупке (фиксированная высота 170)
            HStack {
                certificateImageView()
                    .frame(height: 140)
                    .cornerRadius(15)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )

                if let buyUrl = certificate.buyUrl, let url = URL(string: buyUrl) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Text("Купить")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.trailing, 12)
                }
            }
            .frame(maxWidth: .infinity) // Растягиваем на всю ширину
            .padding(.horizontal, 10) // Уменьшаем отступы для маленьких экранов
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 5)
        }
    }

    // Функция для отображения изображения с кэшированием
    @ViewBuilder
    private func certificateImageView() -> some View {
        ZStack {
            if let imageUrl = certificate.imageUrl {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.2)
                        .overlay(ProgressView())
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
                    .foregroundColor(.gray)
            }
        }
    }

    // Форматирование даты на русский язык
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
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
                    createdDate: Date(),
                    expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
                    imageUrl: "https://24balance.hb.bizmrg.com/certificates/1000.png",
                    buyUrl: nil,
                    expirationText: "Бессрочный",
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
                    expirationText: nil,
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
