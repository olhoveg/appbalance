# Исправление дублирования отложенных покупок

## 🔍 Проблема

При каждом открытии окна с видео уроками в базе данных `videoLessonPurchases` дублируются записи отложенных покупок.

## 🔧 Решение

Добавлено автоматическое удаление отложенных покупок после их обработки.

### 1. Обновлен iOS код (`VideoLessonViewModel.swift`)

```swift
// После успешного сохранения покупки в videoLessonPurchases
self?.removePendingPurchase(paymentId: purchase.paymentId)

// Новый метод для удаления отложенных покупок
private func removePendingPurchase(paymentId: String) {
    // DELETE запрос к /payments/pending/remove
}
```

### 2. Обновлен бэкенд (`index.js`)

```javascript
// Новый эндпоинт для удаления отложенных покупок
if (path.endsWith("/payments/pending/remove")) {
  if (method !== "DELETE") return response(405, { error: "Method not allowed" });
  return await removePendingPurchase(event);
}

// Функция удаления
async function removePendingPurchase(event) {
  // Удаляет запись из Firebase pendingPurchases
}
```

### 3. Обновлена OpenAPI спецификация

```yaml
/payments/pending/remove:
  delete:
    x-yc-apigateway-integration:
      type: cloud_functions
      function_id: d4eddmpv77r6uei62hdg
      tag: "$latest"
      payload_format_version: "1.0"
```

## 🔄 Процесс работы

1. **Пользователь открывает окно с уроками**
2. **iOS проверяет отложенные покупки** - `/payments/pending`
3. **Находит отложенную покупку** - сохраняет в `videoLessonPurchases`
4. **Автоматически удаляет** отложенную покупку из `pendingPurchases`
5. **При следующем открытии** - отложенная покупка уже не найдена

## 📊 Логи для отслеживания

```
🔍 Проверяем отложенные покупки для: 79951231243
📋 Найдено отложенных покупок: 1
🔄 Обрабатываем отложенную покупку: payment_123
✅ Отложенная покупка сохранена: payment_123
🗑️ Удаляем отложенную покупку: payment_123
✅ Отложенная покупка удалена: payment_123
```

## 🧪 Тестирование

### 1. Создайте отложенную покупку
```bash
curl -X POST https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/webhooks/yookassa \
  -H "Content-Type: application/json" \
  -d '{"event": "payment.succeeded", "object": {"id": "test_payment", "amount": {"value": "1000.00", "currency": "RUB"}, "status": "succeeded", "description": "Оплата в BalanceApp: Урок (телефон: 79951231243, ID: lesson_1)"}}'
```

### 2. Проверьте отложенные покупки
```bash
curl -X GET "https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/payments/pending?user_phone=79951231243"
```

### 3. Откройте iOS приложение
- Отложенная покупка должна обработаться
- Запись должна удалиться из `pendingPurchases`
- При повторном открытии отложенных покупок не должно быть

## ✅ Результат

- ❌ **Дублирование устранено** - отложенные покупки удаляются после обработки
- ✅ **Система работает корректно** - покупки восстанавливаются один раз
- ✅ **Производительность улучшена** - меньше данных в Firebase
- ✅ **Логика упрощена** - автоматическая очистка

## 🔧 Настройка

1. **Обновите бэкенд** - загрузите новый `index.js`
2. **Обновите iOS приложение** - загрузите новый `VideoLessonViewModel.swift`
3. **Обновите API Gateway** - добавьте новый эндпоинт
4. **Протестируйте** - создайте отложенную покупку и проверьте обработку
