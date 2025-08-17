import Foundation
import FirebaseDatabase

struct VideoLessonPurchase: Identifiable, Codable {
    let id: String // Firebase document ID
    let userId: String // номер телефона пользователя
    let videoLessonId: String // ID видео урока
    let purchaseDate: Date
    let price: Int
    let paymentMethod: String? // метод оплаты (если применимо)
    let transactionId: String? // ID транзакции (если применимо)
    
    enum CodingKeys: String, CodingKey {
        case id, userId, videoLessonId, price, paymentMethod, transactionId
        case purchaseDate = "purchase_date"
    }
    
    // Инициализатор для создания новой покупки
    init(userId: String, videoLessonId: String, price: Int, paymentMethod: String? = nil, transactionId: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.videoLessonId = videoLessonId
        self.purchaseDate = Date()
        self.price = price
        self.paymentMethod = paymentMethod
        self.transactionId = transactionId
    }
    
    // Инициализатор для создания из словаря Firebase
    init?(from dict: [String: Any], id: String) {
        guard let userId = dict["userId"] as? String,
              let videoLessonId = dict["videoLessonId"] as? String,
              let price = dict["price"] as? Int else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.videoLessonId = videoLessonId
        self.price = price
        self.paymentMethod = dict["paymentMethod"] as? String
        self.transactionId = dict["transactionId"] as? String
        
        // Парсинг даты покупки
        if let purchaseDateTimestamp = dict["purchase_date"] as? TimeInterval {
            self.purchaseDate = Date(timeIntervalSince1970: purchaseDateTimestamp)
        } else {
            self.purchaseDate = Date()
        }
    }
    
    // Преобразование в словарь для Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "videoLessonId": videoLessonId,
            "price": price,
            "purchase_date": purchaseDate.timeIntervalSince1970
        ]
        
        if let paymentMethod = paymentMethod {
            dict["paymentMethod"] = paymentMethod
        }
        if let transactionId = transactionId {
            dict["transactionId"] = transactionId
        }
        
        return dict
    }
}
