import Foundation
import FirebaseDatabase
import SwiftUI

class AbonementImageLoader: ObservableObject {
    @Published var imageUrl: String? = nil
    // Статический кэш для сохранения imageUrl по ключу
    private static var urlCache: [String: String] = [:]
    
    let key: String  // Например, название типа абонемента
    
    init(key: String) {
        self.key = key
        print("AbonementImageLoader init for key: \(key)")
    }
    
    func loadImage() {
        // Если уже есть в кэше, используем его
        if let cachedUrl = AbonementImageLoader.urlCache[key] {
            print("Значение найдено в кэше для ключа: \(key) -> \(cachedUrl)")
            DispatchQueue.main.async {
                self.imageUrl = cachedUrl
            }
            return
        }
        
        print("Значение не найдено в кэше для ключа: \(key). Запрашиваем из Firebase...")
        let db = Database.database().reference()
        let ref = db.child("abonement_images").child(key)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? [String: Any],
               let url = data["image_url"] as? String {
                print("Получено значение image_url для ключа \(self.key): \(url)")
                DispatchQueue.main.async {
                    AbonementImageLoader.urlCache[self.key] = url
                    self.imageUrl = url
                }
            } else {
                print("Firebase не вернул image_url для ключа \(self.key)")
                DispatchQueue.main.async {
                    self.imageUrl = ""
                }
            }
        }
    }
}
