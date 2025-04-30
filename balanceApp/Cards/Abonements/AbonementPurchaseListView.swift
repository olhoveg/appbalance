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
    @State private var loadedPurchaseIndices: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Купить абонемент")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)

            // Пробегаемся с индексом, чтобы задать задержку
            ForEach(Array(purchases.enumerated()), id: \.element.id) { index, purchase in
                HStack(spacing: 12) {
                    GeometryReader { geometry in
                        AsyncImage(url: URL(string: purchase.imageURL)) { phase in
                            ZStack {
                                // базовый серый фон
                                Color.gray.opacity(0.15)
                                
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        // когда картинка загрузилась, отмечаем индекс
                                        .opacity(loadedPurchaseIndices.contains(index) ? 1 : 0)
                                        .onAppear {
                                            loadedPurchaseIndices.insert(index)
                                        }
                                case .failure:
                                    // просто оставляем серый фон
                                    Color.gray.opacity(0.15)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .frame(
                            width: geometry.size.width * 0.8,
                            height: geometry.size.height
                        )
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        )
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.15)

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
                            .foregroundColor(Color.primary)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.2)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                // Fade-in + очередь появления
                .opacity(loadedPurchaseIndices.contains(index) ? 1 : 0)
                .animation(
                    .easeInOut(duration: 0.35)
                        .delay(Double(index) * 0.05),
                    value: loadedPurchaseIndices
                )
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
                          let price = value["price"] as? Int else { continue }
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
