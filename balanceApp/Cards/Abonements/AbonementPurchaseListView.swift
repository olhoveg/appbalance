import SwiftUI
import FirebaseDatabase

struct AbonementPurchase: Identifiable {
    let id: String
    let imageURL: String
    let buyURL: String
    let price: Int
    let order: Int
}

struct AbonementPurchaseListView: View {
    @State private var purchases: [AbonementPurchase] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Купить абонемент")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
            
            ForEach(purchases) { purchase in
                HStack(spacing: 12) {
                    // Изображение (80% доступной ширины)
                    GeometryReader { geometry in
                        AsyncImage(url: URL(string: purchase.imageURL)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Color.gray
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(
                            width: geometry.size.width * 0.8, // 80% ширины контейнера
                            height: geometry.size.height // Высота зависит от контейнера
                        )
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        )
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.15) // Динамическая высота
                    
                    // Боковая колонка (20% доступной ширины)
                    VStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: purchase.buyURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Купить")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Text("\(purchase.price) ₽")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.2) // 20% ширины экрана
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity) // Растягиваем на всю ширину
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            fetchPurchases()
        }
    }
    
    private func fetchPurchases() {
        let dbRef = Database.database().reference()
        let ref = dbRef.child("abonement_images")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? [String: [String: Any]] {
                var items: [AbonementPurchase] = []
                for (key, value) in data {
                    guard let order = value["order"] as? Int,
                          let imageURL = value["image_url"] as? String,
                          let buyURL = value["buy_url"] as? String,
                          let price = value["price"] as? Int
                    else { continue }
                    items.append(
                        AbonementPurchase(
                            id: key,
                            imageURL: imageURL,
                            buyURL: buyURL,
                            price: price,
                            order: order
                        )
                    )
                }
                items.sort { $0.order < $1.order }
                DispatchQueue.main.async {
                    self.purchases = items
                }
            }
        }
    }
}
