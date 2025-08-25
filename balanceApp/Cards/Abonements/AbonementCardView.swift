import SwiftUI
import FirebaseDatabase

struct AbonementCardView: View {
    let abonement: Abonement
    let phoneNumber: String
    // Вместо отдельного состояния для загруженного изображения, будем читать из глобального кэша
    @EnvironmentObject var imageCache: ImageCache
    // Используем отдельный loader для получения imageUrl из Firebase – он остаётся один для данного ключа
    @StateObject private var imageLoader: AbonementImageLoader
    // Локальная копия картинки до попадания в кеш
    @State private var loadedImage: UIImage? = nil
    /// Флаг для плавного fade-in после загрузки изображения
    @State private var isImageLoaded: Bool = false

    @Environment(\.colorScheme) var colorScheme

    init(abonement: Abonement, phoneNumber: String) {
        self.abonement = abonement
        self.phoneNumber = phoneNumber
        // Инициализируем loader с ключом, например, названием типа абонемента
        _imageLoader = StateObject(wrappedValue: AbonementImageLoader(key: abonement.type.title))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    // Серый placeholder – база для плавного появления
                    Color.gray.opacity(0.15)

                    if let url = imageLoader.imageUrl, !url.isEmpty {
                        if let entry = imageCache.cachedImages[url] {
                            Image(uiImage: entry.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(isImageLoaded ? 1 : 0)
                                .animation(.easeInOut(duration: 0.35), value: isImageLoaded)
                                .onAppear { isImageLoaded = true }
                        } else if let img = loadedImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(isImageLoaded ? 1 : 0)
                                .animation(.easeInOut(duration: 0.35), value: isImageLoaded)
                                .onAppear { isImageLoaded = true }
                        } else {
                            ProgressView()
                                .onAppear {
                                    imageCache.loadImage(from: url) { image in
                                        self.loadedImage = image
                                        withAnimation {
                                            self.isImageLoaded = true
                                        }
                                    }
                                }
                        }
                    }
                }
                .frame(height: 240)
                .clipped()

                // Номер абонемента – поверх изображения
                Text("№ \(abonement.number)")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(8)
            }
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
            )
            
            Text(displayBalance())
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
                .padding(.top, 8)
            
            Text("Дата покупки: \(formattedDate(abonement.createdDate))")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
            
            if let expDate = abonement.expirationDate {
                Text("Срок окончания: \(formattedDate(expDate))")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let expText = abonement.expirationText {
                Text("Срок окончания: \(expText)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Срок окончания: Бессрочный")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        .cornerRadius(20)
        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            // Если URL еще не загружен, запускаем загрузку из Firebase
            if imageLoader.imageUrl == nil {
                imageLoader.loadImage()
            }
        }
    }
    
    private func displayBalance() -> String {
        if let balanceStr = abonement.balanceString {
            let pattern = "\\(x(\\d+)\\)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: balanceStr, range: NSRange(location: 0, length: balanceStr.utf16.count)),
               let range = Range(match.range(at: 1), in: balanceStr) {
                let countStr = String(balanceStr[range])
                if let count = Int(countStr) {
                    return formatBalance(count: count, title: abonement.type.title)
                }
            }
        }
        
        if let count = abonement.united_balance_services_count {
            return formatBalance(count: count, title: abonement.type.title)
        }
        
        if let container = abonement.balanceContainer {
            let total = container.links.reduce(0) { $0 + $1.count }
            if total > 0 {
                return formatBalance(count: total, title: abonement.type.title)
            }
        }
        
        return "Баланс: 0"
    }
    
    private func formatBalance(count: Int, title: String) -> String {
        let lowerTitle = title.lowercased()
        let isSolarium = lowerTitle.contains("солярий")
        
        if isSolarium {
            return "Баланс: \(count) \(pluralizeMinutes(count: count))"
        } else {
            return "Баланс: \(count) \(pluralizeSessions(count: count))"
        }
    }
    
    private func pluralizeSessions(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "сеансов"
        } else if rem10 == 1 {
            return "сеанс"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "сеанса"
        } else {
            return "сеансов"
        }
    }
    
    private func pluralizeMinutes(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "минут"
        } else if rem10 == 1 {
            return "минута"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "минуты"
        } else {
            return "минут"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
