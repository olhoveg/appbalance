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
                    // Отображение баланса
                    Text("Баланс: \(certificate.balance) ₽")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)

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

                VStack(alignment: .leading, spacing: 8) {
                    // Отображение баланса
                    Text("Баланс: \(certificate.balance) ₽")
                        .font(.headline)
                        .foregroundColor(.primary)

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
                    }
                }
                .padding(.trailing, 12)
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
