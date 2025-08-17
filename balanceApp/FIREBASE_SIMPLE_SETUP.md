# Простая настройка Firebase для отложенных покупок

## 🔧 Проблема

Firebase REST API требует аутентификации. Для простого решения настроим публичные правила.

## 📋 Шаги настройки

### 1. Перейдите в Firebase Console
- Откройте: https://console.firebase.google.com/
- Выберите проект: `balance-ddb48`

### 2. Настройте Realtime Database Rules
- Перейдите в **Realtime Database** → **Rules**
- Замените правила на:

```json
{
  "rules": {
    "pendingPurchases": {
      ".indexOn": ["userPhone", "status"],
      ".read": true,
      ".write": true
    },
    "videoLessonPurchases": {
      ".indexOn": ["userId", "videoLessonId"],
      ".read": true,
      ".write": true
    },
    "videoLessons": {
      ".indexOn": ["isActive", "category"],
      ".read": true,
      ".write": "auth != null"
    },
    "adminPhones": {
      ".read": true,
      ".write": "auth != null"
    }
  }
}
```

### 3. Проверьте URL базы данных
- В **Realtime Database** → **Data** найдите URL
- Должен быть: `https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app`

### 4. Протестируйте сохранение
```bash
curl -X PUT "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app/pendingPurchases/test123.json" \
  -H "Content-Type: application/json" \
  -d '{"paymentId":"test123","amount":"1000.00","userPhone":"79951231243","status":"succeeded"}'
```

### 5. Протестируйте чтение
```bash
curl -X GET "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app/pendingPurchases.json?orderBy=\"userPhone\"&equalTo=\"79951231243\""
```

## ✅ После настройки

1. **Обновите бэкенд** - загрузите новый `index.js`
2. **Протестируйте webhook** - создайте тестовый платеж
3. **Проверьте iOS** - запустите приложение

## 🔒 Безопасность

⚠️ **Внимание**: Публичные правила подходят только для тестирования. Для продакшена настройте аутентификацию.

## 🚀 Альтернатива: Firebase Admin SDK

Если нужна безопасность, настройте Service Account:

1. **Service accounts** → **Generate new private key**
2. Добавьте переменные окружения в Yandex Cloud
3. Используйте Firebase Admin SDK
