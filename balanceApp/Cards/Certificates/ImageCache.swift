import SwiftUI

// Определяем структуру для записи кэшированного изображения с отметкой времени
struct CachedImageEntry {
    let image: UIImage
    let timestamp: Date
}

class ImageCache: ObservableObject {
    static let shared = ImageCache()
    // Используем словарь для хранения записей, где ключ – URL строки
    @Published var cachedImages: [String: CachedImageEntry] = [:]
    
    // Интервал истечения срока действия кэша – 1 час (3600 секунд)
    let expirationInterval: TimeInterval = 3600
    
    func loadImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        // Проверяем, есть ли запись в кэше для данного URL
        if let entry = cachedImages[url] {
            let elapsed = Date().timeIntervalSince(entry.timestamp)
            if elapsed < expirationInterval {
                print("ImageCache: возвращаем закэшированное изображение для URL: \(url)")
                completion(entry.image)
                return
            } else {
                print("ImageCache: закэшированное изображение устарело для URL: \(url)")
                // Удаляем устаревшую запись
                cachedImages.removeValue(forKey: url)
            }
        }
        
        guard let imageUrl = URL(string: url) else {
            completion(nil)
            return
        }
        
        // Загружаем изображение в фоновом потоке
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: imageUrl),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    // Сохраняем изображение в кэше с текущим временем
                    self.cachedImages[url] = CachedImageEntry(image: image, timestamp: Date())
                    print("ImageCache: изображение успешно загружено для URL: \(url)")
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
