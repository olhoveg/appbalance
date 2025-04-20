import SwiftUI
import FirebaseDatabase

struct CertificateCardView: View {
    let certificate: Certificate
    let isOwned: Bool
    // Используем общий кэш из окружения
    @EnvironmentObject var imageCache: ImageCache
    @State private var loadedImage: UIImage? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isOwned {
            // Для купленных сертификатов – карточка с изображением, номером, балансом, датами и т.д.
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
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .padding(.top, 8)
                    
                    if let purchaseDate = certificate.createdDate {
                        Text("Дата покупки: \(formattedDate(purchaseDate))")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    }
                    
                    if let expDate = certificate.expirationDate {
                        Text("Срок действия: \(formattedDate(expDate))")
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
            // Для сертификатов, доступных к покупке — оформление как у абонементов
            HStack {
                certificateImageView()
                    .frame(width: 220, height: 140)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if let buyUrl = certificate.buyUrl, let url = URL(string: buyUrl) {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            Text("Купить")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }

                    if let price = certificate.defaultBalance {
                        Text("\(price) ₽")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func certificateImageView() -> some View {
        ZStack {
            if let imageUrl = certificate.imageUrl, !imageUrl.isEmpty {
                if let entry = imageCache.cachedImages[imageUrl] {
                    Image(uiImage: entry.image)
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
