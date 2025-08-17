# Настройка Firebase для системы видео уроков

## Структура базы данных Firebase

### 1. Структура для видео уроков

```json
{
  "videoLessons": {
    "adminPhones": {
      "79001234567": true,
      "79009876543": true
    },
    "lesson_id_1": {
      "title": "Основы массажа спины",
      "description": "Подробный видео урок по технике массажа спины",
      "price": 1500,
      "video_url": "https://storage.example.com/video1.mp4",
      "thumbnail_url": "https://storage.example.com/thumb1.jpg",
      "duration": 1800,
      "category": "Массаж",
      "instructor": "Анна Петрова",
      "is_active": true,
      "created_at": 1640995200,
      "updated_at": 1640995200
    },
    "lesson_id_2": {
      "title": "Техника глубокого массажа",
      "description": "Продвинутые техники массажа",
      "price": 2500,
      "video_url": "https://storage.example.com/video2.mp4",
      "thumbnail_url": "https://storage.example.com/thumb2.jpg",
      "duration": 2400,
      "category": "Массаж",
      "instructor": "Михаил Соколов",
      "is_active": true,
      "created_at": 1640995200,
      "updated_at": 1640995200
    }
  }
}
```

### 2. Структура для покупок

```json
{
  "videoLessonPurchases": {
    "purchase_id_1": {
      "userId": "79001234567",
      "videoLessonId": "lesson_id_1",
      "price": 1500,
      "purchase_date": 1640995200,
      "paymentMethod": "card",
      "transactionId": "txn_123456"
    },
    "purchase_id_2": {
      "userId": "79001234567",
      "videoLessonId": "lesson_id_2",
      "price": 2500,
      "purchase_date": 1640995200,
      "paymentMethod": "balance",
      "transactionId": null
    }
  }
}
```

## Правила безопасности Firebase

### 1. Правила для видео уроков

```javascript
{
  "rules": {
    "videoLessons": {
      "adminPhones": {
        ".read": "auth != null",
        ".write": "auth != null && root.child('videoLessons/adminPhones').child(auth.token.phone_number).exists()"
      },
      "$lessonId": {
        ".read": "auth != null",
        ".write": "auth != null && root.child('videoLessons/adminPhones').child(auth.token.phone_number).exists()"
      }
    },
    "videoLessonPurchases": {
      "$purchaseId": {
        ".read": "auth != null && (data.child('userId').val() == auth.token.phone_number || root.child('videoLessons/adminPhones').child(auth.token.phone_number).exists())",
        ".write": "auth != null && (newData.child('userId').val() == auth.token.phone_number || root.child('videoLessons/adminPhones').child(auth.token.phone_number).exists())"
      }
    }
  }
}
```

## Настройка админов

### 1. Добавление админов через Firebase Console

1. Откройте Firebase Console
2. Перейдите в Realtime Database
3. Создайте структуру:
   ```
   videoLessons/
   └── adminPhones/
       ├── 79001234567: true
       └── 79009876543: true
   ```

### 2. Добавление админов программно

```swift
// В VideoLessonViewModel добавьте метод:
func addAdmin(phoneNumber: String, completion: @escaping (Bool) -> Void) {
    databaseRef.child("videoLessons/adminPhones").child(phoneNumber).setValue(true) { error, _ in
        DispatchQueue.main.async {
            if error == nil {
                self.adminPhones.append(phoneNumber)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
```

## Интеграция с yclients

### 1. Проверка авторизации пользователя

```swift
// В VideoLessonViewModel добавьте метод проверки авторизации:
private func checkUserAuthorization(phone: String, completion: @escaping (Bool) -> Void) {
    // Проверяем, авторизован ли пользователь через yclients
    guard let url = URL(string: "https://api.yclients.com/api/v1/group/415038/clients/?phone=\(phone)") else {
        completion(false)
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success {
                completion(true)
            } else {
                completion(false)
            }
        }
    }.resume()
}
```

### 2. Проверка покупок пользователя

```swift
// Обновите методы в VideoLessonViewModel:
private func checkIfUserPurchasedLesson(userId: String, lessonId: String) -> Bool {
    // В реальной реализации здесь будет проверка в Firebase
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

private func getPurchaseDate(userId: String, lessonId: String) -> Date? {
    var purchaseDate: Date?
    let semaphore = DispatchSemaphore(value: 0)
    
    databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: userId).observeSingleEvent(of: .value) { snapshot in
        if let purchases = snapshot.value as? [String: [String: Any]] {
            for (_, purchaseData) in purchases {
                if let videoLessonId = purchaseData["videoLessonId"] as? String,
                   videoLessonId == lessonId,
                   let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                    purchaseDate = Date(timeIntervalSince1970: timestamp)
                    break
                }
            }
        }
        semaphore.signal()
    }
    
    _ = semaphore.wait(timeout: .now() + 5.0)
    return purchaseDate
}
```

## Настройка VK Cloud для хранения файлов

### 1. Конфигурация VKCloudUploader

Убедитесь, что `VKCloudUploader` настроен для загрузки файлов в папку `videoLessons/`:

```swift
// В VKCloudUploader.swift проверьте настройки:
private let baseURL = "https://your-vk-cloud-storage.com"
private let bucketName = "your-bucket-name"
```

### 2. Структура папок в VK Cloud

```
videoLessons/
├── videos/
│   ├── lesson_id_1.mp4
│   ├── lesson_id_2.mp4
│   └── ...
└── thumbnails/
    ├── lesson_id_1.jpg
    ├── lesson_id_2.jpg
    └── ...
```

## Тестирование

### 1. Создание тестовых данных

```swift
// Добавьте в VideoLessonViewModel метод для создания тестовых данных:
func createTestData() {
    let testLessons = [
        VideoLesson(
            id: "test_1",
            title: "Тестовый видео урок 1",
            description: "Описание тестового урока",
            price: 1000,
            videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
            thumbnailUrl: "https://picsum.photos/300/200?random=1",
            duration: 1800,
            category: "Тест",
            instructor: "Тестовый инструктор",
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    
    for lesson in testLessons {
        addVideoLesson(lesson) { _ in }
    }
}
```

### 2. Проверка админских прав

```swift
// Добавьте тестовый номер телефона админа:
func addTestAdmin() {
    addAdmin(phoneNumber: "79001234567") { success in
        print("Тестовый админ добавлен: \(success)")
    }
}
```

## Мониторинг и аналитика

### 1. Firebase Analytics

Добавьте события для отслеживания:

```swift
// В VideoLessonViewModel:
import FirebaseAnalytics

// При покупке видео урока:
Analytics.logEvent("video_lesson_purchased", parameters: [
    "lesson_id": lessonId,
    "price": price,
    "user_id": userId
])

// При просмотре видео урока:
Analytics.logEvent("video_lesson_watched", parameters: [
    "lesson_id": lessonId,
    "user_id": userId
])
```

### 2. Мониторинг ошибок

```swift
// Добавьте обработку ошибок:
func handleError(_ error: Error, context: String) {
    print("❌ Ошибка в \(context): \(error.localizedDescription)")
    
    // Отправка в Firebase Crashlytics
    Crashlytics.crashlytics().record(error: error)
    
    // Отправка в AppMetrica
    AppMetrica.reportEvent(name: "Video Lesson Error", parameters: [
        "context": context,
        "error": error.localizedDescription
    ])
}
```

## Безопасность

### 1. Валидация данных

```swift
// Добавьте валидацию в VideoLessonViewModel:
private func validateVideoLesson(_ lesson: VideoLesson) -> Bool {
    guard !lesson.title.isEmpty,
          !lesson.description.isEmpty,
          lesson.price > 0,
          !lesson.videoUrl.isEmpty else {
        return false
    }
    return true
}
```

### 2. Ограничение размера файлов

```swift
// В VideoLessonAdminView добавьте проверку размера:
private func validateVideoFile(_ data: Data) -> Bool {
    let maxSize = 500 * 1024 * 1024 // 500 MB
    return data.count <= maxSize
}
```

## Развертывание

### 1. Продакшен настройки

1. Обновите Firebase конфигурацию для продакшена
2. Настройте правила безопасности
3. Добавьте реальных админов
4. Настройте мониторинг и алерты

### 2. Тестирование в продакшене

1. Создайте тестовые видео уроки
2. Проверьте покупки и просмотры
3. Протестируйте админские функции
4. Проверьте аналитику и мониторинг
