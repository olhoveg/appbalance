import SwiftUI
import FirebaseDatabase

struct CertificateCardView: View {
    let certificate: Certificate
    let isOwned: Bool
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isOwned {
            // Купленные сертификаты (фиксированная высота ~320)
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    certificateImageView()
                        .frame(height: 200)
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
                    Text("Баланс: \(certificate.balance) ₽")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    // Дата покупки стилизована как в абонементах
                    if let purchaseDate = certificate.createdDate {
                        Text("Дата покупки: \(formattedDate(purchaseDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Срок действия стилизован аналогично
                    if let expirationDate = certificate.expirationDate {
                        Text("Срок действия: \(formattedDate(expirationDate))")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if let expText = certificate.expirationText {
                        Text("Срок действия: \(expText)")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Срок действия: Бессрочный")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding([.leading, .trailing, .bottom])
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
            .cornerRadius(15)
            .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 5)
        } else {
            // Сертификаты, доступные к покупке - без внешнего контейнера и без баланса
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
                }
            }
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
    
    // Форматирование даты на русский язык, как в абонементах
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
