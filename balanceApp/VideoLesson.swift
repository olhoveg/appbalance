import Foundation
import FirebaseDatabase

struct VideoLesson: Identifiable, Codable {
    let id: String // Firebase document ID
    let title: String
    let description: String
    let price: Int
    let videoUrl: String
    let thumbnailUrl: String?
    let duration: Int? // в секундах
    let category: String?
    let instructor: String?
    var isActive: Bool // активен ли урок для покупки
    let createdAt: Date?
    var updatedAt: Date?
    
    // Система акций и скидок
    var discount: Discount?
    
    // Локальные поля для отображения
    var isPurchased: Bool = false
    var purchaseDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, instructor
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case duration, isActive, createdAt, updatedAt
    }
    
    // Инициализатор для создания из Firebase
    init(id: String, title: String, description: String, price: Int, videoUrl: String, thumbnailUrl: String?, duration: Int?, category: String?, instructor: String?, isActive: Bool = true, createdAt: Date? = nil, updatedAt: Date? = nil, discount: Discount? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.category = category
        self.instructor = instructor
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.discount = discount
    }
    
    // Инициализатор для создания из словаря Firebase
    init?(from dict: [String: Any], id: String) {
        guard let title = dict["title"] as? String,
              let description = dict["description"] as? String,
              let price = dict["price"] as? Int,
              let videoUrl = dict["video_url"] as? String else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.videoUrl = videoUrl
        self.thumbnailUrl = dict["thumbnail_url"] as? String
        self.duration = dict["duration"] as? Int
        self.category = dict["category"] as? String
        self.instructor = dict["instructor"] as? String
        self.isActive = dict["is_active"] as? Bool ?? true
        
        // Парсинг скидки
        if let discountDict = dict["discount"] as? [String: Any] {
            self.discount = Discount(from: discountDict)
        } else {
            self.discount = nil
        }
        
        // Парсинг дат
        if let createdAtTimestamp = dict["created_at"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        } else {
            self.createdAt = nil
        }
        
        if let updatedAtTimestamp = dict["updated_at"] as? TimeInterval {
            self.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        } else {
            self.updatedAt = nil
        }
    }
}

// MARK: - Модель скидки
struct Discount: Codable {
    let percentage: Int // процент скидки (например, 20 = 20%)
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case percentage, isActive
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    init(percentage: Int, startDate: Date, endDate: Date, isActive: Bool = true) {
        self.percentage = percentage
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
    }
    
    // Проверка, активна ли скидка сейчас
    var isCurrentlyActive: Bool {
        let now = Date()
        return isActive && now >= startDate && now <= endDate
    }
    
    // Вычисление цены со скидкой
    func discountedPrice(from originalPrice: Int) -> Int {
        let discountAmount = originalPrice * percentage / 100
        return max(originalPrice - discountAmount, 0)
    }
    
    // Инициализатор для создания из словаря Firebase
    init?(from dict: [String: Any]) {
        guard let percentage = dict["percentage"] as? Int,
              let isActive = dict["isActive"] as? Bool else {
            return nil
        }
        
        self.percentage = percentage
        self.isActive = isActive
        
        // Парсинг дат
        if let startDateTimestamp = dict["start_date"] as? TimeInterval {
            self.startDate = Date(timeIntervalSince1970: startDateTimestamp)
        } else {
            self.startDate = Date()
        }
        
        if let endDateTimestamp = dict["end_date"] as? TimeInterval {
            self.endDate = Date(timeIntervalSince1970: endDateTimestamp)
        } else {
            self.endDate = Date().addingTimeInterval(24 * 60 * 60) // +1 день по умолчанию
        }
    }
    
    // Преобразование в словарь для Firebase
    func toDictionary() -> [String: Any] {
        return [
            "percentage": percentage,
            "start_date": startDate.timeIntervalSince1970,
            "end_date": endDate.timeIntervalSince1970,
            "isActive": isActive
        ]
    }
}

// MARK: - Расширения для VideoLesson
extension VideoLesson {
    // Текущая цена (с учетом скидки)
    var currentPrice: Int {
        if let discount = discount, discount.isCurrentlyActive {
            return discount.discountedPrice(from: price)
        }
        return price
    }
    
    // Есть ли активная скидка
    var hasActiveDiscount: Bool {
        return discount?.isCurrentlyActive == true
    }
    
    // Процент скидки
    var discountPercentage: Int? {
        return discount?.isCurrentlyActive == true ? discount?.percentage : nil
    }
    
    // Оригинальная цена (для отображения зачеркнутой цены)
    var originalPrice: Int {
        return price
    }
    
    // Преобразование в словарь для Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "description": description,
            "price": price,
            "video_url": videoUrl,
            "is_active": isActive
        ]
        
        if let thumbnailUrl = thumbnailUrl {
            dict["thumbnail_url"] = thumbnailUrl
        }
        if let duration = duration {
            dict["duration"] = duration
        }
        if let category = category {
            dict["category"] = category
        }
        if let instructor = instructor {
            dict["instructor"] = instructor
        }
        
        // Добавляем скидку
        if let discount = discount {
            dict["discount"] = discount.toDictionary()
        }
        
        if let createdAt = createdAt {
            dict["created_at"] = createdAt.timeIntervalSince1970
        }
        if let updatedAt = updatedAt {
            dict["updated_at"] = updatedAt.timeIntervalSince1970
        }
        
        return dict
    }
}

struct VideoLessonResponse: Codable {
    let success: Bool
    let data: [VideoLesson]
    let meta: VideoLessonMeta
}

struct VideoLessonMeta: Codable {
    let count: Int
    let totalPages: Int?
    let currentPage: Int?
    
    enum CodingKeys: String, CodingKey {
        case count
        case totalPages = "total_pages"
        case currentPage = "current_page"
    }
}
