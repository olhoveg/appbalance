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
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // Изображение карты, занимающее всю ширину
                if let imageUrl = imageUrl, !imageUrl.isEmpty {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(height: 200)
                            .overlay(ProgressView())
                            .clipped()
                            .onAppear {
                                imageCache.loadImage(from: imageUrl) { img in
                                    loadedImage = img
                                }
                            }
                    }
                } else {
                    Image(defaultImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                }
                
                // Номер карты, отображается справа сверху
                Text("№ \(bonusCard.number)")
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding([.top, .trailing], 12)
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
            
            // Баланс карты, красиво оформленный под изображением
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Баланс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.2f", bonusCard.balance)) ₽")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.blue)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .onAppear {
            fetchBonusCardImage()
        }
    }
    
    private func fetchBonusCardImage() {
        let dbRef = Database.database(url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app").reference()
        let ref = dbRef.child("bonuscard_image")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                // Сначала проверяем верхний уровень
                if let title = dict["title"] as? String,
                   let url = dict["image_url"] as? String,
                   title.lowercased() == bonusCard.type.title.lowercased() {
                    DispatchQueue.main.async {
                        self.imageUrl = url
                    }
                    return
                }
                // Ищем вложенный словарь с ключом, равным bonusCard.type.title
                if let nested = dict[bonusCard.type.title] as? [String: Any],
                   let nestedUrl = nested["image_url"] as? String {
                    DispatchQueue.main.async {
                        self.imageUrl = nestedUrl
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.imageUrl = ""
                }
            }
        }
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
    }
}
