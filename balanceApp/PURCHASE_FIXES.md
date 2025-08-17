# Исправление проблем с системой покупок видео уроков

## Проблема
Пользователь покупает видео урок, но при повторном заходе на страницу ему снова предлагается купить то же видео.

## Причина
Методы `checkIfUserPurchasedLesson` и `getPurchaseDate` возвращали фиксированные значения и не проверяли реальные данные из Firebase.

## Решение

### 1. Обновлен метод `fetchVideoLessons`
Теперь метод сначала загружает покупки пользователя, а затем видео уроки, правильно устанавливая статус покупки:

```swift
func fetchVideoLessons(phone: String) {
    // Сначала загружаем покупки пользователя
    databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: phone).observeSingleEvent(of: .value) { [weak self] purchaseSnapshot in
        // Создаем словарь покупок для быстрого поиска
        var userPurchases: [String: Date] = [:]
        if let purchases = purchaseSnapshot.value as? [String: [String: Any]] {
            for (_, purchaseData) in purchases {
                if let videoLessonId = purchaseData["videoLessonId"] as? String,
                   let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                    userPurchases[videoLessonId] = Date(timeIntervalSince1970: timestamp)
                }
            }
        }
        
        // Теперь загружаем видео уроки и устанавливаем статус покупки
        self.databaseRef.child("videoLessons").observeSingleEvent(of: .value) { [weak self] lessonSnapshot in
            // Устанавливаем статус покупки для каждого урока
            lesson.isPurchased = userPurchases[lessonId] != nil
            if lesson.isPurchased {
                lesson.purchaseDate = userPurchases[lessonId]
            }
        }
    }
}
```

### 2. Обновлены методы проверки покупок
Методы теперь реально проверяют данные в Firebase:

```swift
private func checkIfUserPurchasedLesson(userId: String, lessonId: String) -> Bool {
    // Проверяем покупки в Firebase
    var isPurchased = false
    let semaphore = DispatchSemaphore(value: 0)
    
    databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: userId).observeSingleEvent(of: .value) { snapshot in
        if let purchases = snapshot.value as? [String: [String: Any]] {
            for (_, purchaseData) in purchases {
                if let videoLessonId = purchaseData["videoLessonId"] as? String,
                   videoLessonId == lessonId {
                    isPurchased = true
                    break
                }
            }
        }
        semaphore.signal()
    }
    
    _ = semaphore.wait(timeout: .now() + 5.0)
    return isPurchased
}
```

### 3. Добавлен метод обновления статуса покупки
```swift
func updatePurchaseStatus(for lessonId: String, userId: String) {
    // Проверяем, купил ли пользователь этот урок
    databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: userId).observeSingleEvent(of: .value) { [weak self] snapshot in
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            if let index = self?.videoLessons.firstIndex(where: { $0.id == lessonId }) {
                self?.videoLessons[index].isPurchased = isPurchased
                self?.videoLessons[index].purchaseDate = purchaseDate
            }
        }
    }
}
```

### 4. Обновлен VideoLessonsView
Добавлено обновление данных при возвращении в приложение:

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    // Обновляем данные при возвращении в приложение
    if !userPhone.isEmpty {
        viewModel.refreshVideoLessons(phone: userPhone)
    }
}
```

## Тестирование

### 1. Создан тестовый файл VideoLessonPurchaseTest.swift
Позволяет проверить:
- Загрузку данных
- Статус покупок
- Процесс покупки
- Обновление данных

### 2. Проверка в Firebase Console
Убедитесь, что в базе данных создаются записи в `videoLessonPurchases`:
```json
{
  "videoLessonPurchases": {
    "purchase_id": {
      "userId": "79001234567",
      "videoLessonId": "lesson_id",
      "price": 1500,
      "purchase_date": 1640995200
    }
  }
}
```

## Структура данных

### Покупка видео урока
```swift
struct VideoLessonPurchase: Identifiable, Codable {
    let id: String // Firebase document ID
    let userId: String // номер телефона пользователя
    let videoLessonId: String // ID видео урока
    let purchaseDate: Date
    let price: Int
    let paymentMethod: String?
    let transactionId: String?
}
```

### Статус покупки в VideoLesson
```swift
struct VideoLesson: Identifiable, Codable {
    // ... основные поля ...
    
    // Локальные поля для отображения
    var isPurchased: Bool = false
    var purchaseDate: Date?
}
```

## Проверка работы

1. **Покупите видео урок** - должен появиться в Firebase
2. **Перезапустите приложение** - статус покупки должен сохраниться
3. **Проверьте раздел "Мои видео уроки"** - купленное видео должно отображаться
4. **Попробуйте купить то же видео** - должно показывать "Смотреть" вместо "Купить"

## Возможные проблемы

### Если покупки все еще не сохраняются:
1. Проверьте подключение к Firebase
2. Убедитесь, что правила безопасности позволяют записывать в `videoLessonPurchases`
3. Проверьте консоль на наличие ошибок

### Если данные загружаются медленно:
1. Оптимизируйте запросы к Firebase
2. Добавьте кэширование локальных данных
3. Используйте индикаторы загрузки

## Следующие улучшения

1. **Кэширование покупок** - сохранять покупки локально для быстрого доступа
2. **Синхронизация в реальном времени** - использовать Firebase listeners
3. **Офлайн поддержка** - работать с покупками без интернета
4. **Аналитика покупок** - отслеживать статистику и метрики
