import Foundation
import UIKit

class YooKassaPaymentService: ObservableObject {
    static let shared = YooKassaPaymentService()
    
    private init() {}
    
    // MARK: - Создание платежа (временная версия)
    
    func createPayment(
        for lesson: VideoLesson,
        userPhone: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Временная реализация - симулируем успешный платеж
        print("🎯 Mock: Создание платежа для урока: \(lesson.title)")
        print("   Сумма: \(lesson.currentPrice) руб.")
        print("   Пользователь: \(userPhone)")
        print("   Текущая цена: \(lesson.currentPrice)")
        print("   Оригинальная цена: \(lesson.originalPrice)")
        
        // Симулируем задержку обработки
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Генерируем тестовый токен
            let testToken = "mock_payment_\(UUID().uuidString)"
            
            print("✅ Mock: Платеж успешно создан")
            print("   Token: \(testToken)")
            
            // Отправляем уведомление об успехе
            NotificationCenter.default.post(
                name: .ykPaymentSuccess,
                object: nil,
                userInfo: ["token": testToken]
            )
            
            completion(.success(testToken))
        }
    }
}

// MARK: - Уведомления

extension Notification.Name {
    static let ykPaymentSuccess = Notification.Name("ykPaymentSuccess")
    static let ykPaymentError = Notification.Name("ykPaymentError")
}

// MARK: - Ошибки

enum PaymentError: Error, LocalizedError {
    case presentationError
    case tokenizationError
    case validationError
    
    var errorDescription: String? {
        switch self {
        case .presentationError:
            return "Ошибка отображения экрана оплаты"
        case .tokenizationError:
            return "Ошибка создания платежа"
        case .validationError:
            return "Ошибка валидации данных"
        }
    }
}
