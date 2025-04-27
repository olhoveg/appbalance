import SwiftUI
import FirebaseDatabase

struct BonusBlockCardView: View {
    let bonusCard: BonusCard
    @State private var imageUrl: String? = nil
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil
    @State private var imageLoaded: Bool = false    // New state for animation

    var body: some View {
        ZStack {
            // Skeleton placeholder shown while the card loads
            VStack(spacing: 12) {
                // Grey rectangle where the card image will appear
                Color.gray.opacity(0.2)
                    .frame(height: 200)
                    .cornerRadius(12)

                // Grey bars imitating the “Баланс” caption and the amount
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Color.gray.opacity(0.2)
                            .frame(width: 70, height: 18)
                            .cornerRadius(4)

                        Color.gray.opacity(0.2)
                            .frame(width: 110, height: 22)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
            .opacity(imageLoaded ? 0 : 1)

            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Container for image and placeholder with fade animation
                    ZStack {
                        // Placeholder
                        Color.gray.opacity(0.2)
                            .frame(height: 200)
                            .overlay(ProgressView())
                            .clipped()
                            .opacity(imageLoaded ? 0 : 1)

                        // Loaded image
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .opacity(imageLoaded ? 1 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)

                    // Номер карты, отображается справа сверху
                    Text("№ \(bonusCard.number)")
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding([.top, .trailing], 12)
                }

                // Баланс карты, красиво оформленный под изображением
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Баланс")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", bonusCard.balance)) ₽")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
            }
            .opacity(imageLoaded ? 1 : 0)
            .padding(.horizontal)
        }
        .animation(.easeInOut(duration: 0.4), value: imageLoaded)
        .onAppear {
            fetchBonusCardImage()
        }
    }
    
    private func fetchBonusCardImage() {
        let dbRef = Database.database(url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app").reference()
        let ref = dbRef.child("bonuscard_image")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                // выбираем URL как ранее
                var selectedURL: String? = nil
                if let title = dict["title"] as? String,
                   let url = dict["image_url"] as? String,
                   title.lowercased() == bonusCard.type.title.lowercased() {
                    selectedURL = url
                } else if let nested = dict[bonusCard.type.title] as? [String: Any],
                          let nestedUrl = nested["image_url"] as? String {
                    selectedURL = nestedUrl
                }
                DispatchQueue.main.async {
                    self.imageUrl = selectedURL
                    if let urlString = selectedURL {
                        imageCache.loadImage(from: urlString) { img in
                            loadedImage = img
                            withAnimation {
                                imageLoaded = true
                            }
                        }
                    }
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
