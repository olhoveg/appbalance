# Интеграция ЮKassa для платежей

## Обзор

Интеграция ЮKassa позволяет пользователям оплачивать видео уроки через безопасную платежную систему.

## Настройка

### 1. Добавление SDK ЮKassa

В Xcode добавьте зависимость ЮKassa:

1. Откройте проект в Xcode
2. Выберите File → Add Package Dependencies
3. Вставьте URL: `https://github.com/yoomoney/yookassa-payments-swift`
4. Выберите версию: `8.0.1`
5. Нажмите Add Package

### 2. API ключ

Используется тестовый ключ: `test_NzczNzU3V4O1jhaBdcAJ927ujxZKwYPRNm1lNvYbsfE`

**ВНИМАНИЕ**: Для продакшена замените на боевой ключ!

### 3. Конфигурация

В `Info.plist` добавьте:

```xml
<key>NSCameraUsageDescription</key>
<string>Приложению требуется доступ к камере для сканирования карт</string>
```

## Архитектура

### YooKassaPaymentService

Основной сервис для работы с платежами:

```swift
class YooKassaPaymentService: ObservableObject {
    static let shared = YooKassaPaymentService()
    
    func createPayment(
        for lesson: VideoLesson,
        userPhone: String,
        completion: @escaping (Result<String, Error>) -> Void
    )
}
```

### Интеграция с ViewModel

`VideoLessonViewModel` обновлен для работы с ЮKassa:

- `isProcessingPayment` - состояние обработки платежа
- `purchaseVideoLesson()` - создает платеж через ЮKassa
- `savePurchase()` - сохраняет покупку после успешного платежа

## Процесс покупки

### 1. Пользователь нажимает "Купить"

```swift
Button(action: {
    onPurchase(lesson)
}) {
    // UI кнопки
}
```

### 2. Создание платежа

```swift
YooKassaPaymentService.shared.createPayment(
    for: lesson,
    userPhone: phone
) { result in
    // Обработка результата
}
```

### 3. Открытие экрана оплаты

ЮKassa открывает нативный экран оплаты с:
- Вводом данных карты
- Подтверждением платежа
- Безопасной обработкой

### 4. Обработка результата

```swift
// Успешный платеж
NotificationCenter.default.post(name: .paymentSuccess, object: nil)

// Ошибка платежа
NotificationCenter.default.post(name: .paymentError, object: nil)
```

### 5. Сохранение покупки

После успешного платежа:
- Создается запись в Firebase
- Обновляется UI
- Отправляется аналитика

## UI обновления

### Индикатор загрузки

Кнопки показывают состояние обработки:

```swift
if viewModel.isProcessingPayment {
    ProgressView()
        .scaleEffect(0.8)
        .progressViewStyle(CircularProgressViewStyle(tint: .white))
} else {
    Image(systemName: "cart")
}
```

### Блокировка кнопок

Во время обработки платежа кнопки блокируются:

```swift
.disabled(viewModel.isProcessingPayment)
```

## Тестирование

### Тестовые карты

Используйте тестовые карты ЮKassa:

- **Успешный платеж**: `1111 1111 1111 1026`
- **Недостаточно средств**: `1111 1111 1111 1049`
- **Карта заблокирована**: `1111 1111 1111 1051`

### Тестовые данные

- **Срок действия**: любой будущий месяц/год
- **CVV**: любые 3 цифры
- **Имя владельца**: любые символы

## Аналитика

Отправляются события в AppMetrica:

```swift
AppMetrica.reportEvent(name: "Пользователь купил видео урок", parameters: [
    "video_id": lesson.id,
    "video_title": lesson.title,
    "price": lesson.currentPrice,
    "payment_method": "YooKassa",
    "payment_token": paymentToken
])
```

## Безопасность

### Токенизация

ЮKassa использует токенизацию:
- Данные карты не передаются в приложение
- Создается безопасный токен для платежа
- Токен передается на сервер для подтверждения

### Валидация

- Проверка суммы платежа
- Валидация данных карты
- Проверка статуса платежа

## Обработка ошибок

### Типы ошибок

```swift
enum PaymentError: Error, LocalizedError {
    case presentationError
    case tokenizationError
    case validationError
}
```

### Пользовательские сообщения

```swift
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
```

## Продакшен

### Замена API ключа

1. Получите боевой ключ в личном кабинете ЮKassa
2. Замените в `YooKassaPaymentService.swift`:

```swift
clientApplicationKey: "ВАШ_БОЕВОЙ_КЛЮЧ"
```

### Настройка уведомлений

Настройте webhook для получения уведомлений о платежах:

```swift
// URL для уведомлений
let webhookUrl = "https://your-server.com/payment-webhook"
```

### Мониторинг

- Отслеживайте успешность платежей
- Мониторьте ошибки
- Анализируйте конверсию

## Поддержка

### Документация

- [Официальная документация ЮKassa](https://yookassa.ru/developers)
- [SDK для iOS](https://github.com/yoomoney/yookassa-payments-swift)

### Контакты

- Техподдержка ЮKassa: support@yookassa.ru
- Документация по API: https://yookassa.ru/developers/api

## Примеры использования

### Создание платежа

```swift
let lesson = VideoLesson(...)
let userPhone = "+79001234567"

YooKassaPaymentService.shared.createPayment(
    for: lesson,
    userPhone: userPhone
) { result in
    switch result {
    case .success(let token):
        print("Платеж создан: \(token)")
    case .failure(let error):
        print("Ошибка: \(error)")
    }
}
```

### Обработка уведомлений

```swift
NotificationCenter.default.addObserver(
    forName: .paymentSuccess,
    object: nil,
    queue: .main
) { notification in
    if let token = notification.userInfo?["token"] as? Tokens {
        // Обработка успешного платежа
    }
}
```
