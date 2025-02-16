import SwiftUI
import FirebaseDatabase

struct BonusBlockCardView: View {
    let bonusCard: BonusCard
    @State private var imageUrl: String? = nil
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil
    
    // Имя изображения по умолчанию (убедитесь, что оно добавлено в Assets.xcassets)
    private let defaultImageName = "defaultBonusImage"
    
    var body: some View {
        VStack(spacing: 8) {
            // Квадратное изображение бонусной карты с обводкой и скруглением
            ZStack {
                if let imageUrl = imageUrl, !imageUrl.isEmpty {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(width: 150, height: 150)
                            .cornerRadius(12)
                            .overlay(ProgressView())
                            .onAppear {
                                imageCache.loadImage(from: imageUrl) { img in
                                    loadedImage = img
                                }
                            }
                    }
                } else {
                    Image(defaultImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            
            // Номер бонусной карты
            Text("№ \(bonusCard.number)")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            // Баланс карты
            Text("Баланс: \(String(format: "%.2f", bonusCard.balance)) ₽")
                .font(.subheadline)
                .foregroundColor(.blue)
            
            // Блок истории операций (если есть)
            if let transactions = bonusCard.transactions, !transactions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("История операций")
                        .font(.footnote)
                        .bold()
                    ForEach(transactions) { transaction in
                        HStack {
                            Text(transaction.type == "Начисление" ? "Начислено:" : "Списано:")
                                .font(.caption)
                            Text("\(String(format: "%.2f", transaction.amount)) ₽")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formattedDate(transaction.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        // Убираем общий фон и контейнер
        .onAppear {
            fetchBonusCardImage()
        }
    }
    
    private func fetchBonusCardImage() {
        let dbRef = Database.database(url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app").reference()
        let ref = dbRef.child("bonuscard_image")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            print("Snapshot bonuscard_image: \(snapshot.value ?? "nil")")
            if let dict = snapshot.value as? [String: Any] {
                // Сначала проверяем верхний уровень
                if let title = dict["title"] as? String,
                   let url = dict["image_url"] as? String {
                    print("Найдено на верхнем уровне: \(title) - \(url)")
                    if title.lowercased() == bonusCard.type.title.lowercased() {
                        DispatchQueue.main.async {
                            self.imageUrl = url
                        }
                        return
                    }
                }
                // Ищем вложенный словарь с ключом, равным bonusCard.type.title
                if let nested = dict[bonusCard.type.title] as? [String: Any],
                   let nestedUrl = nested["image_url"] as? String {
                    print("Найдено во вложенном словаре: \(bonusCard.type.title) - \(nestedUrl)")
                    DispatchQueue.main.async {
                        self.imageUrl = nestedUrl
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.imageUrl = ""
                }
            } else {
                print("Нет данных для bonuscard_image")
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

struct BonusBlockCardView_Previews: PreviewProvider {
    static var previews: some View {
        BonusBlockCardView(bonusCard: BonusCard(
            id: 51883748,
            number: "777",
            balance: 798.55,
            points: 0,
            paidAmount: 26934,
            soldAmount: 53118,
            visitsCount: 410,
            typeId: 45913,
            salonGroupId: 415038,
            maxDiscountPercent: 0,
            maxDiscountAmount: 0,
            type: BonusCardType(
                id: 45913,
                title: "Бонусная карта",
                salonGroupId: 415038,
                serviceItemType: "any_allowed",
                goodItemType: "any_allowed"
            ),
            transactions: [
                BonusCardTransaction(type: "Начисление", amount: 100, date: Date()),
                BonusCardTransaction(type: "Списание", amount: 50, date: Date())
            ]
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
