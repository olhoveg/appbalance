# Быстрая настройка ЮKassa

## Шаги для интеграции

### 1. Добавить SDK в Xcode

1. Откройте `balanceApp.xcodeproj` в Xcode
2. Выберите проект → Package Dependencies
3. Нажмите "+" → Add Package
4. Вставьте URL: `https://github.com/yoomoney/yookassa-payments-swift`
5. Выберите версию `8.0.1`
6. Нажмите "Add Package"

### 2. Добавить разрешения в Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>Приложению требуется доступ к камере для сканирования карт</string>
```

### 3. Проверить API ключ

В `YooKassaPaymentService.swift` уже установлен тестовый ключ:
```swift
clientApplicationKey: "test_NzczNzU3V4O1jhaBdcAJ927ujxZKwYPRNm1lNvYbsfE"
```

### 4. Собрать проект

```bash
cd balanceApp
xcodebuild -project ../balanceApp.xcodeproj -scheme balanceApp -destination 'platform=iOS Simulator,name=iPhone 16' build
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

После настройки пользователи смогут:
- ✅ Платить за видео уроки через ЮKassa
- ✅ Видеть индикатор обработки платежа
- ✅ Получать уведомления об успехе/ошибке
- ✅ Автоматически получать доступ к купленным урокам

## Для продакшена

1. Получите боевой ключ в [личном кабинете ЮKassa](https://yookassa.ru/)
2. Замените тестовый ключ на боевой
3. Настройте webhook для уведомлений
4. Протестируйте на реальных картах
