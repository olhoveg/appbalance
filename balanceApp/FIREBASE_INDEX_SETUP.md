# Настройка индексов Firebase для улучшения производительности

## ⚠️ Предупреждение Firebase

```
[FirebaseDatabase][I-RDB034028] Using an unspecified index. Your data will be downloaded and filtered on the client. Consider adding ".indexOn": "userId" at /videoLessonPurchases to your security rules for better performance
```

## 🔧 Решение

### Обновите правила безопасности Firebase Realtime Database:

```json
{
  "rules": {
    "videoLessonPurchases": {
      ".indexOn": ["userId", "videoLessonId"],
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "pendingPurchases": {
      ".indexOn": ["userPhone", "status"],
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "videoLessons": {
      ".indexOn": ["isActive", "category"],
      ".read": true,
      ".write": "auth != null"
    },
    "adminPhones": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

## 📊 Индексы для оптимизации

### 1. **videoLessonPurchases**
- `userId` - для быстрого поиска покупок пользователя
- `videoLessonId` - для проверки покупки конкретного урока

### 2. **pendingPurchases**
- `userPhone` - для поиска отложенных покупок пользователя
- `status` - для фильтрации по статусу платежа

### 3. **videoLessons**
- `isActive` - для фильтрации активных уроков
- `category` - для фильтрации по категориям

## 🚀 Преимущества индексов

1. **Быстрый поиск** - данные фильтруются на сервере, а не на клиенте
2. **Меньше трафика** - передаются только нужные данные
3. **Лучшая производительность** - особенно при большом количестве записей
4. **Экономия ресурсов** - меньше нагрузка на устройство пользователя

## 🔍 Как проверить

После обновления правил Firebase:

1. Перезапустите приложение
2. Проверьте логи - предупреждение должно исчезнуть
3. Заметите улучшение производительности при загрузке данных

## 📝 Примечания

- Индексы создаются автоматически при первом запросе
- Может потребоваться некоторое время для создания индексов
- При большом количестве данных индексы особенно важны
