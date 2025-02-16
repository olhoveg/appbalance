//
//  AbonementImagesList.swift
//  balanceApp
//
//  Created by Evgen on 16.02.2025.
//

import SwiftUI
import FirebaseDatabase

// Модель данных абонемента (изображения)
struct AbonementImageModel: Identifiable {
    let id: String
    let imageURL: String
    let buyURL: String
    let price: Int
    let order: Int
}

struct AbonementImagesList: View {
    @State private var abonements: [AbonementImageModel] = []
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(abonements) { item in
                HStack {
                    // Изображение занимает примерно 70% ширины
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .cover)
                        } else if phase.error != nil {
                            Color.gray
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.7, height: 170)
                    .clipped()
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    // Боковая колонка: кнопка "Купить" и цена
                    VStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: item.buyURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Купить")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Text("\(item.price) ₽")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
        .onAppear {
            fetchAbonementImages()
        }
    }
    
    private func fetchAbonementImages() {
        let dbRef = Database.database().reference()
        let imagesRef = dbRef.child("abonement_images")
        imagesRef.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: [String: Any]] else {
                print("Не удалось получить данные абонементов")
                return
            }
            
            var items: [AbonementImageModel] = []
            for (key, value) in data {
                // Фильтруем элементы, у которых нет поля order
                guard let order = value["order"] as? Int else { continue }
                guard let imageURL = value["image_url"] as? String else { continue }
                guard let buyURL = value["buy_url"] as? String else { continue }
                guard let price = value["price"] as? Int else { continue }
                
                let item = AbonementImageModel(id: key, imageURL: imageURL, buyURL: buyURL, price: price, order: order)
                items.append(item)
            }
            // Сортируем по order
            items.sort { $0.order < $1.order }
            DispatchQueue.main.async {
                self.abonements = items
            }
        }
    }
}

struct AbonementImagesList_Previews: PreviewProvider {
    static var previews: some View {
        AbonementImagesList()
    }
}
