import Foundation
import SwiftUI
import FirebaseDatabase
import AppMetricaCore
import YooKassaPayments

class VideoLessonViewModel: ObservableObject {
    @Published var videoLessons: [VideoLesson] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var adminPhones: [String] = []
    @Published var isProcessingPayment = false
    
    let databaseRef = Database.database().reference()
    
    var isAdmin: Bool {
        if let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            return adminPhones.contains(savedPhone)
        }
        return false
    }
    
    func fetchVideoLessons(phone: String) {
        isLoading = true
        errorMessage = nil
        
        // Загружаем список админов
        loadAdminPhones()
        
        // Сначала загружаем покупки пользователя
        databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: phone).observeSingleEvent(of: .value) { [weak self] purchaseSnapshot in
            guard let self = self else { return }
            
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
            
            // Теперь загружаем видео уроки
            self.databaseRef.child("videoLessons").observeSingleEvent(of: .value) { [weak self] lessonSnapshot in
                guard let self = self else { return }
                
                var lessons: [VideoLesson] = []
                
                if let lessonsDict = lessonSnapshot.value as? [String: [String: Any]] {
                    for (lessonId, lessonData) in lessonsDict {
                        if var lesson = VideoLesson(from: lessonData, id: lessonId) {
                            // Проверяем, купил ли пользователь этот урок
                            lesson.isPurchased = userPurchases[lessonId] != nil
                            if lesson.isPurchased {
                                lesson.purchaseDate = userPurchases[lessonId]
                            }
                            lessons.append(lesson)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.videoLessons = lessons.filter { $0.isActive } // Показываем только активные уроки
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadAdminPhones() {
        databaseRef.child("videoLessons/adminPhones").observeSingleEvent(of: .value) { [weak self] snapshot, _ in
            if let phonesDict = snapshot.value as? [String: Any] {
                DispatchQueue.main.async {
                    self?.adminPhones = Array(phonesDict.keys)
                }
            }
        }
    }
    
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
    
    private func getPurchaseDate(userId: String, lessonId: String) -> Date? {
        // Получаем дату покупки из Firebase
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
    
    // MARK: - Вспомогательные методы для Firebase
    
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
    
    func createTestData() {
        let testLessons = [
            VideoLesson(
                id: "lesson_1",
                title: "Основы массажа спины",
                description: "Подробный видео урок по технике массажа спины для начинающих. Изучите основные приемы и правильную последовательность движений.",
                price: 1500,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=1",
                duration: 1800,
                category: "Массаж",
                instructor: "Анна Петрова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_2",
                title: "Техника глубокого массажа",
                description: "Продвинутые техники глубокого массажа для опытных специалистов. Работа с глубокими мышцами и фасциями.",
                price: 2500,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=2",
                duration: 2400,
                category: "Массаж",
                instructor: "Михаил Соколов",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_3",
                title: "СПА процедуры для лица",
                description: "Комплексный уход за лицом с использованием профессиональных средств и техник.",
                price: 1200,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=3",
                duration: 1500,
                category: "Уход за лицом",
                instructor: "Елена Иванова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_4",
                title: "Антицеллюлитный массаж",
                description: "Эффективные техники антицеллюлитного массажа для коррекции фигуры и улучшения состояния кожи.",
                price: 1800,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=4",
                duration: 2100,
                category: "Коррекция фигуры",
                instructor: "Ольга Сидорова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_5",
                title: "Массаж стоп и рефлексотерапия",
                description: "Техники массажа стоп с элементами рефлексотерапии для расслабления и оздоровления всего организма.",
                price: 1000,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=5",
                duration: 1200,
                category: "Релаксация",
                instructor: "Дмитрий Козлов",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_6",
                title: "Профессиональный макияж",
                description: "Создание идеального макияжа для любого случая. От повседневного до вечернего образа.",
                price: 2000,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=6",
                duration: 2700,
                category: "Макияж",
                instructor: "Мария Волкова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_7",
                title: "Уход за волосами",
                description: "Профессиональные техники ухода за волосами, включая массаж головы и правильное расчесывание.",
                price: 900,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=7",
                duration: 900,
                category: "Уход за волосами",
                instructor: "Ирина Морозова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            VideoLesson(
                id: "lesson_8",
                title: "Ароматерапия и массаж",
                description: "Сочетание ароматерапии с массажными техниками для максимального расслабления и оздоровления.",
                price: 2200,
                videoUrl: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
                thumbnailUrl: "https://picsum.photos/300/200?random=8",
                duration: 3000,
                category: "Ароматерапия",
                instructor: "Анна Петрова",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        for lesson in testLessons {
            addVideoLesson(lesson) { success in
                print("Тестовый урок '\(lesson.title)' добавлен: \(success)")
            }
        }
    }
    
    // MARK: - Покупка видео уроков
    
    func purchaseVideoLesson(videoId: String, phone: String, completion: @escaping (Bool) -> Void) {
        guard let lesson = videoLessons.first(where: { $0.id == videoId }) else {
            completion(false)
            return
        }
        
        // Проверяем, не куплен ли уже урок
        if lesson.isPurchased {
            completion(true)
            return
        }
        
        isProcessingPayment = true
        
        // Создаем платеж через ЮKassa
        YooKassaRealPaymentService.shared.createPayment(for: lesson, userPhone: phone) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessingPayment = false
                
                switch result {
                case .success(let token):
                    // Платеж успешно создан, сохраняем покупку
                    self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token, completion: completion)
                    
                case .failure(let error):
                    self?.errorMessage = "Ошибка платежа: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
        
        // Подписываемся на уведомления о результате платежа
        setupPaymentNotifications(videoId: videoId, phone: phone, lesson: lesson, completion: completion)
    }
    
    private func savePurchase(lesson: VideoLesson, phone: String, paymentToken: String, completion: @escaping (Bool) -> Void) {
        // Создаем запись о покупке
        let purchase = VideoLessonPurchase(
            userId: phone,
            videoLessonId: lesson.id,
            price: lesson.currentPrice,
            paymentMethod: "YooKassa",
            transactionId: paymentToken
        )
        
        // Сохраняем в Firebase
        databaseRef.child("videoLessonPurchases").child(purchase.id).setValue(purchase.toDictionary()) { [weak self] error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    // Обновляем локальный статус
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == lesson.id }) {
                        self?.videoLessons[index].isPurchased = true
                        self?.videoLessons[index].purchaseDate = purchase.purchaseDate
                    }
                    
                    // Отправляем аналитику
                    AppMetrica.reportEvent(name: "Пользователь купил видео урок", parameters: [
                        "video_id": lesson.id,
                        "video_title": lesson.title,
                        "price": lesson.currentPrice,
                        "original_price": lesson.originalPrice,
                        "has_discount": lesson.hasActiveDiscount,
                        "discount_percentage": lesson.discountPercentage ?? 0,
                        "payment_method": "YooKassa",
                        "payment_token": paymentToken
                    ])
                    
                    completion(true)
                } else {
                    self?.errorMessage = "Ошибка сохранения покупки: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                    completion(false)
                }
            }
        }
    }
    
    private func setupPaymentNotifications(videoId: String, phone: String, lesson: VideoLesson, completion: @escaping (Bool) -> Void) {
        print("🔔 Настраиваем уведомления для платежа")
        print("   Video ID: \(videoId)")
        print("   Phone: \(phone)")
        print("   Lesson: \(lesson.title)")
        
        // Подписываемся на успешный платеж
        NotificationCenter.default.addObserver(
            forName: .ykPaymentSuccess,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🎉 Получено уведомление об успешном платеже")
            print("   UserInfo: \(notification.userInfo ?? [:])")
            
            if let token = notification.userInfo?["token"] as? String {
                print("✅ Токен получен: \(token)")
                self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token, completion: completion)
            } else {
                print("❌ Токен не найден в уведомлении")
                completion(false)
            }
            NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentSuccess, object: nil)
        }
        
        // Подписываемся на ошибку платежа
        NotificationCenter.default.addObserver(
            forName: .ykPaymentError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("❌ Получено уведомление об ошибке платежа")
            print("   UserInfo: \(notification.userInfo ?? [:])")
            
            if let error = notification.userInfo?["error"] as? Error {
                print("❌ Ошибка: \(error.localizedDescription)")
                self?.errorMessage = "Ошибка платежа: \(error.localizedDescription)"
                completion(false)
            } else {
                print("❌ Ошибка не найдена в уведомлении")
                self?.errorMessage = "Неизвестная ошибка платежа"
                completion(false)
            }
            NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentError, object: nil)
        }
    }
    
    // MARK: - Админские функции
    
    func addVideoLesson(_ lesson: VideoLesson, completion: @escaping (Bool) -> Void) {
        let lessonDict = lesson.toDictionary()
        databaseRef.child("videoLessons").child(lesson.id).setValue(lessonDict) { [weak self] error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    self?.videoLessons.append(lesson)
                    completion(true)
                } else {
                    self?.errorMessage = "Ошибка добавления: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                    completion(false)
                }
            }
        }
    }
    
    func updateVideoLesson(_ lesson: VideoLesson, completion: @escaping (Bool) -> Void) {
        var lessonDict = lesson.toDictionary()
        lessonDict["updated_at"] = Date().timeIntervalSince1970
        
        databaseRef.child("videoLessons").child(lesson.id).setValue(lessonDict) { [weak self] error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == lesson.id }) {
                        self?.videoLessons[index] = lesson
                    }
                    completion(true)
                } else {
                    self?.errorMessage = "Ошибка обновления: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                    completion(false)
                }
            }
        }
    }
    
    func deleteVideoLesson(_ lessonId: String, completion: @escaping (Bool) -> Void) {
        databaseRef.child("videoLessons").child(lessonId).removeValue { [weak self] error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    self?.videoLessons.removeAll { $0.id == lessonId }
                    completion(true)
                } else {
                    self?.errorMessage = "Ошибка удаления: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                    completion(false)
                }
            }
        }
    }
    
    func toggleVideoLessonActive(_ lessonId: String, completion: @escaping (Bool) -> Void) {
        databaseRef.child("videoLessons").child(lessonId).child("is_active").observeSingleEvent(of: .value) { [weak self] snapshot, _ in
            let newValue = !(snapshot.value as? Bool ?? true)
            
            self?.databaseRef.child("videoLessons").child(lessonId).updateChildValues([
                "is_active": newValue,
                "updated_at": Date().timeIntervalSince1970
            ]) { error, _ in
                DispatchQueue.main.async {
                    if error == nil {
                        if let index = self?.videoLessons.firstIndex(where: { $0.id == lessonId }) {
                            self?.videoLessons[index].isActive = newValue
                        }
                        completion(true)
                    } else {
                        self?.errorMessage = "Ошибка обновления: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                        completion(false)
                    }
                }
            }
        }
    }
    
    // MARK: - Функции управления скидками
    
    func addDiscountToLesson(lessonId: String, discount: Discount, completion: @escaping (Bool) -> Void) {
        guard let lessonIndex = videoLessons.firstIndex(where: { $0.id == lessonId }) else {
            completion(false)
            return
        }
        
        var updatedLesson = videoLessons[lessonIndex]
        updatedLesson.discount = discount
        
        updateVideoLesson(updatedLesson) { success in
            completion(success)
        }
    }
    
    func removeDiscountFromLesson(lessonId: String, completion: @escaping (Bool) -> Void) {
        guard let lessonIndex = videoLessons.firstIndex(where: { $0.id == lessonId }) else {
            completion(false)
            return
        }
        
        var updatedLesson = videoLessons[lessonIndex]
        updatedLesson.discount = nil
        
        updateVideoLesson(updatedLesson) { success in
            completion(success)
        }
    }
    
    func updateDiscountForLesson(lessonId: String, discount: Discount, completion: @escaping (Bool) -> Void) {
        addDiscountToLesson(lessonId: lessonId, discount: discount, completion: completion)
    }
    
    func refreshVideoLessons(phone: String) {
        // Обновляем данные, включая покупки
        fetchVideoLessons(phone: phone)
    }
    
    // MARK: - Метод для обновления статуса покупки в реальном времени
    func updatePurchaseStatus(for lessonId: String, userId: String) {
        // Проверяем, купил ли пользователь этот урок
        databaseRef.child("videoLessonPurchases").queryOrdered(byChild: "userId").queryEqual(toValue: userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            if let purchases = snapshot.value as? [String: [String: Any]] {
                var isPurchased = false
                var purchaseDate: Date?
                
                for (_, purchaseData) in purchases {
                    if let videoLessonId = purchaseData["videoLessonId"] as? String,
                       videoLessonId == lessonId {
                        isPurchased = true
                        if let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                            purchaseDate = Date(timeIntervalSince1970: timestamp)
                        }
                        break
                    }
                }
                
                DispatchQueue.main.async {
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == lessonId }) {
                        self?.videoLessons[index].isPurchased = isPurchased
                        self?.videoLessons[index].purchaseDate = purchaseDate
                    }
                }
            }
        }
    }
    
    func formatDuration(_ seconds: Int?) -> String {
        guard let seconds = seconds else { return "Неизвестно" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    func formatPrice(_ price: Int) -> String {
        return "\(price) ₽"
    }
    
    // MARK: - Загрузка файлов
    
    func uploadVideo(fileURL: URL, progress: @escaping (Double) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        VKCloudUploader.shared.upload(
            fileURL: fileURL,
            fileName: "videoLessons/\(UUID().uuidString).mov",
            progress: progress,
            completion: { result in
                switch result {
                case .success(let url):
                    completion(.success(url.absoluteString))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    func uploadThumbnail(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        VKCloudUploader.shared.upload(
            fileURL: fileURL,
            fileName: "videoLessons/thumbnails/\(UUID().uuidString).jpg",
            progress: { _ in },
            completion: { result in
                switch result {
                case .success(let url):
                    completion(.success(url.absoluteString))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    // MARK: - Отложенные покупки
    
    func checkPendingPurchases(phone: String) {
        print("🔍 Проверяем отложенные покупки для: \(phone)")
        
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "PaymentsBackendURL") as? String,
              let url = URL(string: baseURL + "/payments/pending?user_phone=\(phone)") else {
            print("❌ Ошибка: не удалось создать URL для проверки отложенных покупок")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: req) { [weak self] data, response, err in
            if let err = err {
                print("❌ Ошибка сети при проверке отложенных покупок: \(err)")
                return
            }
            
            guard let data = data else {
                print("❌ Ошибка: пустой ответ при проверке отложенных покупок")
                return
            }
            
            do {
                print("📄 Полученные данные: \(String(data: data, encoding: .utf8) ?? "неизвестно")")
                let pendingResponse = try JSONDecoder().decode(PendingPurchasesResponse.self, from: data)
                print("📋 Найдено отложенных покупок: \(pendingResponse.pendingPurchases.count)")
                
                DispatchQueue.main.async {
                    self?.processPendingPurchases(pendingResponse.pendingPurchases, phone: phone)
                }
            } catch {
                print("❌ Ошибка декодирования отложенных покупок: \(error)")
                print("📄 Сырые данные: \(String(data: data, encoding: .utf8) ?? "неизвестно")")
            }
        }.resume()
    }
    
    private func processPendingPurchases(_ purchases: [PendingPurchase], phone: String) {
        for purchase in purchases {
            print("🔄 Обрабатываем отложенную покупку: \(purchase.paymentId)")
            
            // Проверяем, что у нас есть необходимые данные
            guard let videoLessonId = purchase.videoLessonId else {
                print("❌ Ошибка: отсутствует videoLessonId для покупки \(purchase.paymentId)")
                continue
            }
            
            // Проверяем, что это не тестовая запись
            if purchase.paymentId.hasPrefix("test") {
                print("⏭️ Пропускаем тестовую запись: \(purchase.paymentId)")
                continue
            }
            
            // Создаем запись о покупке
            let videoPurchase = VideoLessonPurchase(
                userId: phone,
                videoLessonId: videoLessonId,
                price: Int(Double(purchase.amount) ?? 0),
                paymentMethod: "YooKassa",
                transactionId: purchase.paymentId
            )
            
            // Сохраняем в Firebase
            databaseRef.child("videoLessonPurchases").child(videoPurchase.id).setValue(videoPurchase.toDictionary()) { [weak self] error, _ in
                if error == nil {
                    print("✅ Отложенная покупка сохранена: \(purchase.paymentId)")
                    
                    // Обновляем локальный статус уроков
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == purchase.videoLessonId }) {
                        self?.videoLessons[index].isPurchased = true
                        self?.videoLessons[index].purchaseDate = videoPurchase.purchaseDate
                    }
                    
                    // Отправляем аналитику
                    AppMetrica.reportEvent(name: "Отложенная покупка обработана", parameters: [
                        "payment_id": purchase.paymentId,
                        "video_lesson_id": purchase.videoLessonId,
                        "amount": purchase.amount
                    ])
                    
                    // Удаляем отложенную покупку после успешной обработки
                    self?.removePendingPurchase(paymentId: purchase.paymentId)
                } else {
                    print("❌ Ошибка сохранения отложенной покупки: \(error?.localizedDescription ?? "неизвестная ошибка")")
                }
            }
        }
    }
    
    private struct PendingPurchasesResponse: Decodable {
        let pendingPurchases: [PendingPurchase]
        
        enum CodingKeys: String, CodingKey {
            case pendingPurchases = "pending_purchases"
        }
    }
    
    private struct PendingPurchase: Decodable {
        let paymentId: String
        let amount: String
        let currency: String?
        let description: String?
        let status: String
        let createdAt: String?
        let userPhone: String?
        let videoLessonId: String?
    }
    
    // MARK: - Удаление отложенных покупок
    
    private func removePendingPurchase(paymentId: String) {
        print("🗑️ Удаляем отложенную покупку: \(paymentId)")
        
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "PaymentsBackendURL") as? String,
              let url = URL(string: baseURL + "/payments/pending/remove") else {
            print("❌ Ошибка: не удалось создать URL для удаления отложенной покупки")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["payment_id": paymentId]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, response, err in
            if let err = err {
                print("❌ Ошибка сети при удалении отложенной покупки: \(err)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Отложенная покупка удалена: \(paymentId)")
                } else {
                    print("❌ Ошибка удаления отложенной покупки: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}
