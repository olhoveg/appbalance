# Правильная настройка ЮKassa

## Проблема

Текущий код использует устаревший API ЮKassa. Нужно обновить интеграцию.

## Решение

### 1. Добавить SDK в проект

В Xcode:
1. File → Add Package Dependencies
2. URL: `https://github.com/yoomoney/yookassa-payments-swift`
3. Версия: `8.0.1`

### 2. Обновить YooKassaPaymentService.swift

Замените содержимое файла на актуальный API:

```swift
import Foundation
import UIKit
import YooKassaPayments

class YooKassaPaymentService: ObservableObject {
    static let shared = YooKassaPaymentService()
    
    private let shopName = "BalanceApp"
    private let purchaseDescription = "Покупка видео урока"
    
    private init() {}
    
    func createPayment(
        for lesson: VideoLesson,
        userPhone: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Создаем токенизацию для платежа
        let tokenizationModuleInput = TokenizationModuleInput(
            amount: Amount(value: Decimal(lesson.currentPrice), currency: .rub),
            title: lesson.title,
            subtitle: purchaseDescription,
            clientApplicationKey: "test_NzczNzU3V4O1jhaBdcAJ927ujxZKwYPRNm1lNvYbsfE",
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            isLoggingEnabled: true,
            tokenizationSettings: TokenizationSettings(paymentMethodTypes: PaymentMethodTypes.all),
            testModeSettings: TestModeSettings(paymentAuthorizationPassed: true),
            cardScanning: CardScanning(isEnabled: false),
            applePay: ApplePay(isEnabled: false),
            shop: Shop(
                name: shopName,
                description: "Видео уроки по массажу"
            ),
            customerId: userPhone,
            savePaymentMethod: SavePaymentMethod.off
        )
        
        // Создаем модуль токенизации
        let tokenizationModule = TokenizationAssembly.makeModule(
            inputData: tokenizationModuleInput,
            moduleOutput: self
        )
        
        // Показываем экран оплаты
        DispatchQueue.main.async {
            if let topViewController = self.getTopViewController() {
                tokenizationModule?.present(from: topViewController)
            } else {
                completion(.failure(PaymentError.presentationError))
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
}

// MARK: - TokenizationModuleOutput

extension YooKassaPaymentService: TokenizationModuleOutput {
    func tokenizationModule(
        _ module: TokenizationModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        print("Токенизация успешна: \(token)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .paymentSuccess,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
    
    func tokenizationModule(
        _ module: TokenizationModuleInput,
        didFailTokenize error: Error
    ) {
        print("Ошибка токенизации: \(error)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .paymentError,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
    
    func tokenizationModule(
        _ module: TokenizationModuleInput,
        didValidate paymentMethodType: PaymentMethodType,
        errors: [Error]
    ) {
        if !errors.isEmpty {
            print("Ошибки валидации: \(errors)")
        }
    }
    
    func tokenizationModuleDidFinish(
        _ module: TokenizationModuleInput,
        error: YooKassaPaymentsError?
    ) {
        if let error = error {
            print("Модуль закрыт с ошибкой: \(error)")
        } else {
            print("Модуль закрыт успешно")
        }
    }
}

// MARK: - Уведомления

extension Notification.Name {
    static let paymentSuccess = Notification.Name("paymentSuccess")
    static let paymentError = Notification.Name("paymentError")
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
```

### 3. Обновить VideoLessonViewModel.swift

Добавьте импорт:

```swift
import YooKassaPayments
```

И обновите метод setupPaymentNotifications:

```swift
private func setupPaymentNotifications(videoId: String, phone: String, lesson: VideoLesson, completion: @escaping (Bool) -> Void) {
    // Подписываемся на успешный платеж
    NotificationCenter.default.addObserver(
        forName: .paymentSuccess,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        if let token = notification.userInfo?["token"] as? Tokens {
            self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token.paymentToken, completion: completion)
        }
        NotificationCenter.default.removeObserver(self as Any, name: .paymentSuccess, object: nil)
    }
    
    // Подписываемся на ошибку платежа
    NotificationCenter.default.addObserver(
        forName: .paymentError,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        if let error = notification.userInfo?["error"] as? Error {
            self?.errorMessage = "Ошибка платежа: \(error.localizedDescription)"
            completion(false)
        }
        NotificationCenter.default.removeObserver(self as Any, name: .paymentError, object: nil)
    }
}
```

### 4. Добавить разрешения в Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>Приложению требуется доступ к камере для сканирования карт</string>
```

## Тестирование

### Тестовые карты

- **Успешный платеж**: `1111 1111 1111 1026`
- **Недостаточно средств**: `1111 1111 1111 1049`
- **Карта заблокирована**: `1111 1111 1111 1051`

### Тестовые данные

- **Срок**: любой будущий месяц/год
- **CVV**: любые 3 цифры
- **Имя**: любые символы

## Готово! 🎉

После этих изменений интеграция с ЮKassa будет работать корректно.
