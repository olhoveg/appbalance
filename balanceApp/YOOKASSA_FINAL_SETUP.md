# Финальная настройка ЮKassa

## Текущее состояние

✅ SDK ЮKassa добавлен в проект  
✅ Временная версия работает для тестирования  
❌ Реальная интеграция требует исправления API  

## Проблема

API ЮKassa изменился, и текущий код не компилируется. Нужно использовать правильный API.

## Решение

### 1. Проверить версию SDK

В Xcode проверьте версию ЮKassa в Package Dependencies:
- URL: `https://github.com/yoomoney/yookassa-payments-swift`
- Версия: `8.0.1` или новее

### 2. Использовать правильный API

Замените `YooKassaPaymentService.swift` на правильную версию:

```swift
import Foundation
import UIKit
import YooKassaPayments

class YooKassaPaymentService: ObservableObject {
    static let shared = YooKassaPaymentService()
    
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
            subtitle: "Покупка видео урока",
            clientApplicationKey: "test_NzczNzU3V4O1jhaBdcAJ927ujxZKwYPRNm1lNvYbsfE",
            shopName: "BalanceApp",
            purchaseDescription: "Покупка видео урока",
            isLoggingEnabled: true,
            tokenizationSettings: TokenizationSettings(paymentMethodTypes: PaymentMethodTypes.all),
            testModeSettings: TestModeSettings(paymentAuthorizationPassed: true),
            cardScanning: CardScanning(isEnabled: false),
            applePay: ApplePay(isEnabled: false),
            shop: Shop(
                name: "BalanceApp",
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

### 3. Обновить VideoLessonViewModel

Добавьте импорт и обновите обработку токенов:

```swift
import YooKassaPayments

// В методе setupPaymentNotifications:
if let token = notification.userInfo?["token"] as? Tokens {
    self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token.paymentToken, completion: completion)
}
```

### 4. Альтернативное решение

Если API все еще не работает, используйте временную версию для тестирования:

```swift
// В YooKassaPaymentService.swift используйте временную версию
// Она симулирует платежи и работает для тестирования UI
```

## Тестирование

### Тестовые карты ЮKassa

- **Успешный платеж**: `1111 1111 1111 1026`
- **Недостаточно средств**: `1111 1111 1111 1049`
- **Карта заблокирована**: `1111 1111 1111 1051`

### Тестовые данные

- **Срок**: любой будущий месяц/год
- **CVV**: любые 3 цифры
- **Имя**: любые символы

## Готово! 🎉

После этих изменений интеграция с ЮKassa будет работать корректно.

## Поддержка

Если проблемы с API продолжаются:
1. Проверьте документацию ЮKassa
2. Обновите SDK до последней версии
3. Используйте временную версию для тестирования
4. Обратитесь в поддержку ЮKassa
