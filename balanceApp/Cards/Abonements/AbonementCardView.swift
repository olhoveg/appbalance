// AbonementCardView.swift
import SwiftUI
import FirebaseDatabase

struct AbonementCardView: View {
    let abonement: Abonement
    let phoneNumber: String
    @State private var imageUrl: String?
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                if let url = imageUrl, !url.isEmpty {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.3)
                            .frame(height: 180)
                            .overlay(ProgressView())
                            .onAppear {
                                imageCache.loadImage(from: url) { img in
                                    loadedImage = img
                                }
                            }
                    }
                } else {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Text("No Image")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .frame(height: 180)
                }
                
                Text("№ \(abonement.number)")
                    .font(.footnote).fontWeight(.bold)
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
                .foregroundColor(.primary)
                .padding(.top, 8)
            
            Text("Дата покупки: \(formattedDate(abonement.createdDate))")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
        .onAppear {
            fetchAbonementImage()
        }
    }
    
    private func fetchAbonementImage() {
        let db = Database.database().reference()
        let key = abonement.type.title
        let ref = db.child("abonement_images").child(key)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? [String: Any],
               let url = data["image_url"] as? String {
                imageUrl = url
            }
        }
    }
    
    private func displayBalance() -> String {
        // 1. Попытка извлечь значение из balanceString
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
        
        // 2. Используем united_balance_services_count
        if let count = abonement.united_balance_services_count {
            return formatBalance(count: count, title: abonement.type.title)
        }
        
        // 3. Суммируем значения из balanceContainer
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
