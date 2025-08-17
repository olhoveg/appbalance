# Настройка Firebase для отложенных покупок

## 📋 Обзор

Система отложенных покупок позволяет пользователям получать доступ к купленному контенту даже если они не вернулись в приложение после оплаты.

## 🔧 Настройка Firebase

### 1. Структура данных в Firebase Realtime Database

```json
{
  "pendingPurchases": {
    "payment_id_123": {
      "paymentId": "payment_id_123",
      "amount": "1000.00",
      "currency": "RUB",
      "description": "Оплата в BalanceApp: Урок йоги (телефон: +79001234567, ID: lesson_123)",
      "status": "succeeded",
      "createdAt": "2024-01-15T10:30:00.000Z",
      "userPhone": "+79001234567",
      "videoLessonId": "lesson_123"
    }
  }
}
```

### 2. Правила безопасности Firebase

```json
{
  "rules": {
    "pendingPurchases": {
      ".read": "auth != null",
      ".write": "auth != null",
      "$paymentId": {
        ".validate": "newData.hasChildren(['paymentId', 'amount', 'status', 'userPhone', 'videoLessonId'])"
      }
    }
  }
}
```

### 3. Переменные окружения для бэкенда

Добавьте в переменные окружения Yandex Cloud Function:

```bash
FIREBASE_DATABASE_URL=https://your-project-id.firebaseio.com
```

## 🔄 Процесс работы

### 1. Создание платежа
- iOS приложение создает платеж через YooKassa
- В описании платежа передается телефон пользователя и ID урока

### 2. Webhook от YooKassa
- При успешной оплате YooKassa отправляет webhook на `/webhooks/yookassa`
- Бэкенд извлекает информацию о пользователе из описания
- Сохраняет отложенную покупку в Firebase

### 3. Проверка отложенных покупок
- iOS приложение при запуске вызывает `/payments/pending?user_phone=+79001234567`
- Бэкенд возвращает список отложенных покупок для пользователя
- iOS приложение обрабатывает покупки и предоставляет доступ к контенту

## 🧪 Тестирование

### Тест webhook'а

```bash
curl -X POST https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/webhooks/yookassa \
  -H "Content-Type: application/json" \
  -d '{
    "event": "payment.succeeded",
    "object": {
      "id": "test_payment_123",
      "amount": {
        "value": "1000.00",
        "currency": "RUB"
      },
      "status": "succeeded",
      "description": "Оплата в BalanceApp: Урок йоги (телефон: +79001234567, ID: lesson_123)"
    }
  }'
```

### Тест получения отложенных покупок

```bash
curl -X GET "https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/payments/pending?user_phone=%2B79001234567"
```

## 📱 Интеграция с iOS

### 1. Автоматическая проверка
- При запуске приложения
- При возвращении в приложение из фона

### 2. Обработка покупок
- Создание записей в `videoLessonPurchases`
- Обновление статуса уроков
- Отправка аналитики

## 🔍 Мониторинг

### Логи для отслеживания

1. **Webhook логи**:
   ```
   Webhook: {"event":"payment.succeeded",...}
   Payment succeeded: {id: "payment_123", ...}
   Pending purchase saved: {paymentId: "payment_123", ...}
   ```

2. **iOS логи**:
   ```
   🔍 Проверяем отложенные покупки для: +79001234567
   📋 Найдено отложенных покупок: 1
   🔄 Обрабатываем отложенную покупку: payment_123
   ✅ Отложенная покупка сохранена: payment_123
   ```

## 🚨 Обработка ошибок

### Возможные проблемы

1. **Неверный формат описания платежа**
   - Проверьте регулярные выражения в `extractUserPhoneFromDescription` и `extractVideoLessonIdFromDescription`

2. **Ошибки Firebase**
   - Проверьте переменную окружения `FIREBASE_DATABASE_URL`
   - Убедитесь в правильности правил безопасности

3. **Дублирование покупок**
   - Используйте `paymentId` как уникальный ключ
   - Проверяйте существование покупки перед сохранением

## 📊 Аналитика

### События для отслеживания

1. **Отложенная покупка обработана**
   - `payment_id`: ID платежа
   - `video_lesson_id`: ID урока
   - `amount`: сумма платежа

2. **Ошибка обработки отложенной покупки**
   - `error`: описание ошибки
   - `payment_id`: ID платежа

## 🔧 Настройка в Yandex Cloud

### 1. Обновление Cloud Function
```bash
# Загрузите обновленный index.js в Yandex Cloud Function
```

### 2. Обновление API Gateway
```bash
# Загрузите обновленную OpenAPI спецификацию
```

### 3. Настройка webhook'ов в YooKassa
- В кабинете YooKassa добавьте webhook URL: `https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/webhooks/yookassa`
- Выберите события: `payment.succeeded`, `payment.canceled`

## ✅ Чек-лист настройки

- [ ] Обновлен `index.js` с поддержкой отложенных покупок
- [ ] Обновлена OpenAPI спецификация
- [ ] Настроена структура Firebase
- [ ] Добавлены переменные окружения
- [ ] Настроены webhook'и в YooKassa
- [ ] Протестированы все эндпоинты
- [ ] Проверена работа в iOS приложении
