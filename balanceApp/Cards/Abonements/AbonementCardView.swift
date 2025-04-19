import SwiftUI
import FirebaseDatabase

struct AbonementCardView: View {
    let abonement: Abonement
    let phoneNumber: String
    // Вместо отдельного состояния для загруженного изображения, будем читать из глобального кэша
    @EnvironmentObject var imageCache: ImageCache
    // Используем отдельный loader для получения imageUrl из Firebase – он остаётся один для данного ключа
    @StateObject private var imageLoader: AbonementImageLoader

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
                // Используем imageLoader.imageUrl для получения URL
                if let url = imageLoader.imageUrl, !url.isEmpty {
                    // Если изображение уже есть в глобальном кэше – используем его немедленно
                    if let entry = imageCache.cachedImages[url] {
                        Image(uiImage: entry.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else {
                        // Если изображения ещё нет в кэше – показываем placeholder и запускаем загрузку
                        Color.gray.opacity(0.3)
                            .frame(height: 200)
                            .overlay(ProgressView())
                            .onAppear {
                                // Загрузка из глобального кэша (если ещё не загружено)
                                imageCache.loadImage(from: url) { _ in }
                            }
                    }
                } else {
                    // Если URL не получен – показываем fallback
                    ZStack {
                        Color.gray.opacity(0.3)
                        Text("No Image")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .frame(height: 200)
                }
                
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
