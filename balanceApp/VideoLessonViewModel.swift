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
    @Published var processingPayments: Set<String> = [] // Индивидуальное состояние загрузки для каждого урока
    
    // Состояния для алертов
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var successMessage = ""
    @Published var errorAlertMessage = ""
    
    let databaseRef = Database.database().reference()
    
    var isAdmin: Bool {
        if let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            return adminPhones.contains(savedPhone)
        }
        return false
    }
    
    // Вспомогательный метод для проверки состояния загрузки конкретного урока
    func isProcessingPayment(for lessonId: String) -> Bool {
        return processingPayments.contains(lessonId)
    }
    
    // Вспомогательный метод для установки состояния загрузки
    func setProcessingPayment(_ isProcessing: Bool, for lessonId: String) {
        DispatchQueue.main.async {
            if isProcessing {
                self.processingPayments.insert(lessonId)
            } else {
                self.processingPayments.remove(lessonId)
            }
        }
    }
    
    // Метод для очистки всех состояний загрузки
    func clearAllProcessingPayments() {
        DispatchQueue.main.async {
            self.processingPayments.removeAll()
        }
    }
    
    func fetchVideoLessons(phone: String) {
        isLoading = true
        errorMessage = nil
        
        // Очищаем все состояния загрузки при загрузке новых данных
        clearAllProcessingPayments()
        
        // Загружаем список админов
        loadAdminPhones()
        
        // Сначала загружаем покупки пользователя
        databaseRef.child("videoLessonPurchases").child(phone).observeSingleEvent(of: .value) { [weak self] purchaseSnapshot in
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
                                print("✅ При загрузке: урок \(lessonId) (\(lesson.title)) - КУПЛЕН")
                            }
                            lessons.append(lesson)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.videoLessons = lessons.filter { $0.isActive } // Показываем только активные уроки
                    self.isLoading = false
                    
                    // Логируем финальное состояние
                    let purchasedCount = self.videoLessons.filter { $0.isPurchased }.count
                    print("📊 Загрузка завершена: \(self.videoLessons.count) уроков, \(purchasedCount) купленных")
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
        
        databaseRef.child("videoLessonPurchases").child(userId).observeSingleEvent(of: .value) { snapshot in
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
        
        databaseRef.child("videoLessonPurchases").child(userId).observeSingleEvent(of: .value) { snapshot in
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
        
        setProcessingPayment(true, for: videoId)
        
        // Создаем платеж через ЮKassa
        YooKassaRealPaymentService.shared.createPayment(for: lesson, userPhone: phone) { [weak self] result in
            DispatchQueue.main.async {
                self?.setProcessingPayment(false, for: videoId)
                
                switch result {
                case .success(let token):
                    // Платеж успешно создан, сохраняем покупку
                    self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token, completion: completion)
                    
                case .failure(let error):
                    self?.errorMessage = "Ошибка платежа: \(error.localizedDescription)"
                    // Очищаем все наблюдатели при ошибке
                    NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentSuccess, object: nil)
                    NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentError, object: nil)
                    NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentCanceled, object: nil)
                    completion(false)
                }
            }
        }
        
        // Подписываемся на уведомления о результате платежа
        setupPaymentNotifications(videoId: videoId, phone: phone, lesson: lesson, completion: completion)
        
        // Добавляем таймаут для автоматического сброса состояния загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) { [weak self] in
            // Если состояние загрузки все еще активно через 60 секунд, сбрасываем его
            if self?.isProcessingPayment(for: videoId) == true {
                print("⏰ Таймаут платежа для урока \(videoId), сбрасываем состояние загрузки")
                self?.setProcessingPayment(false, for: videoId)
                // Очищаем все наблюдатели
                NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentSuccess, object: nil)
                NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentError, object: nil)
                NotificationCenter.default.removeObserver(self as Any, name: .ykPaymentCanceled, object: nil)
                completion(false)
            }
        }
    }
    
    private func savePurchase(lesson: VideoLesson, phone: String, paymentToken: String, completion: @escaping (Bool) -> Void) {
        print("💾 Сохраняем покупку: \(lesson.id) с токеном: \(paymentToken)")
        
        // Сначала проверяем, не существует ли уже такая покупка по transactionId
        databaseRef.child("videoLessonPurchases").child(phone).queryOrdered(byChild: "transactionId").queryEqual(toValue: paymentToken).observeSingleEvent(of: .value) { [weak self] snapshot in
            if let purchases = snapshot.value as? [String: [String: Any]], !purchases.isEmpty {
                print("⚠️ Покупка с токеном \(paymentToken) уже существует, проверяем детали")
                
                // Проверяем, есть ли уже покупка именно для этого урока
                let existingPurchaseForLesson = purchases.values.first { purchaseData in
                    if let videoLessonId = purchaseData["videoLessonId"] as? String {
                        return videoLessonId == lesson.id
                    }
                    return false
                }
                
                if existingPurchaseForLesson != nil {
                    print("✅ Покупка для урока \(lesson.id) уже существует, обновляем локальный статус")
                    // Обновляем локальный статус
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == lesson.id }) {
                        self?.videoLessons[index].isPurchased = true
                    }
                    self?.setProcessingPayment(false, for: lesson.id)
                    completion(true)
                    return
                } else {
                    print("⚠️ Найдена покупка с тем же токеном, но для другого урока. Это может быть ошибка.")
                    // Показываем ошибку пользователю
                    self?.errorAlertMessage = "Обнаружена ошибка: этот платеж уже был использован для другого урока"
                    self?.showErrorAlert = true
                    self?.setProcessingPayment(false, for: lesson.id)
                    completion(false)
                    return
                }
            }
            
            // Создаем запись о покупке
            let purchase = VideoLessonPurchase(
                userId: phone,
                videoLessonId: lesson.id,
                price: lesson.currentPrice,
                paymentMethod: "YooKassa",
                transactionId: paymentToken
            )
            
            print("💾 Создаем новую покупку с ID: \(purchase.id) для телефона: \(phone)")
            
            // Сохраняем в Firebase под номером телефона
            self?.databaseRef.child("videoLessonPurchases").child(phone).child(purchase.id).setValue(purchase.toDictionary()) { [weak self] error, _ in
                DispatchQueue.main.async {
                    if error == nil {
                        print("✅ Покупка успешно сохранена в Firebase")
                        
                        // Обновляем локальное состояние урока
                        if let index = self?.videoLessons.firstIndex(where: { $0.id == lesson.id }) {
                            self?.videoLessons[index].isPurchased = true
                            self?.videoLessons[index].purchaseDate = purchase.purchaseDate
                            print("✅ Локальное состояние урока обновлено: \(lesson.id)")
                        }
                        
                        // Показываем сообщение об успехе
                        self?.successMessage = "Урок успешно куплен!"
                        self?.showSuccessAlert = true
                        
                        // Останавливаем индикатор загрузки
                        self?.setProcessingPayment(false, for: lesson.id)
                        
                        completion(true)
                    } else {
                        print("❌ Ошибка сохранения покупки: \(error?.localizedDescription ?? "неизвестная ошибка")")
                        // Показываем ошибку пользователю
                        self?.errorAlertMessage = "Ошибка сохранения покупки: \(error?.localizedDescription ?? "неизвестная ошибка")"
                        self?.showErrorAlert = true
                        // Останавливаем индикатор загрузки при ошибке
                        self?.setProcessingPayment(false, for: lesson.id)
                        completion(false)
                    }
                }
            }
        }
    }
    
    private func setupPaymentNotifications(videoId: String, phone: String, lesson: VideoLesson, completion: @escaping (Bool) -> Void) {
        print("🔔 Настраиваем уведомления для платежа")
        print("   Video ID: \(videoId)")
        print("   Phone: \(phone)")
        print("   Lesson: \(lesson.title)")
        
        // Флаг для предотвращения множественных вызовов
        var isCompleted = false
        
        // Функция для завершения платежа
        let finishPayment: (Bool) -> Void = { [weak self] success in
            guard let self = self, !isCompleted else { return }
            isCompleted = true
            
            // Очищаем все наблюдатели
            NotificationCenter.default.removeObserver(self, name: .ykPaymentSuccess, object: nil)
            NotificationCenter.default.removeObserver(self, name: .ykPaymentError, object: nil)
            NotificationCenter.default.removeObserver(self, name: .ykPaymentCanceled, object: nil)
            
            completion(success)
        }
        
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
                self?.savePurchase(lesson: lesson, phone: phone, paymentToken: token, completion: finishPayment)
            } else {
                print("❌ Токен не найден в уведомлении")
                self?.setProcessingPayment(false, for: videoId)
                finishPayment(false)
            }
        }
        
        // Подписываемся на отмену платежа
        NotificationCenter.default.addObserver(
            forName: .ykPaymentCanceled,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🚫 Получено уведомление об отмене платежа")
            print("   Video ID: \(videoId)")
            
            // Просто сбрасываем состояние загрузки без показа ошибки
            self?.setProcessingPayment(false, for: videoId)
            finishPayment(false)
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
                self?.errorAlertMessage = "Ошибка платежа: \(error.localizedDescription)"
                self?.showErrorAlert = true
                self?.setProcessingPayment(false, for: videoId)
                finishPayment(false)
            } else {
                print("❌ Ошибка не найден в уведомлении")
                self?.errorAlertMessage = "Неизвестная ошибка платежа"
                self?.showErrorAlert = true
                self?.setProcessingPayment(false, for: videoId)
                finishPayment(false)
            }
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
        // Очищаем все состояния загрузки при обновлении данных
        clearAllProcessingPayments()
        // Обновляем данные, включая покупки
        fetchVideoLessons(phone: phone)
    }
    
    // MARK: - Метод для обновления статуса покупки в реальном времени
    func updatePurchaseStatus(for lessonId: String, userId: String) {
        // Проверяем, купил ли пользователь этот урок
        databaseRef.child("videoLessonPurchases").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
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
    
    // MARK: - Обновление статуса покупки
    
    func refreshPurchaseStatus(for lessonId: String, phone: String) {
        print("🔄 Обновляем статус покупки для урока: \(lessonId)")
        
        databaseRef.child("videoLessonPurchases").child(phone).queryOrdered(byChild: "videoLessonId").queryEqual(toValue: lessonId).observeSingleEvent(of: .value) { [weak self] snapshot in
            DispatchQueue.main.async {
                if let purchases = snapshot.value as? [String: [String: Any]], !purchases.isEmpty {
                    print("✅ Найдена покупка в Firebase для урока: \(lessonId)")
                    
                    // Обновляем локальное состояние
                    if let index = self?.videoLessons.firstIndex(where: { $0.id == lessonId }) {
                        self?.videoLessons[index].isPurchased = true
                        
                        // Получаем дату покупки
                        if let purchaseData = purchases.values.first,
                           let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                            self?.videoLessons[index].purchaseDate = Date(timeIntervalSince1970: timestamp)
                        }
                        
                        print("✅ Локальное состояние обновлено для урока: \(lessonId)")
                        print("   isPurchased = \(self?.videoLessons[index].isPurchased ?? false)")
                        
                        // Принудительно обновляем UI
                        self?.objectWillChange.send()
                    } else {
                        print("❌ Урок \(lessonId) не найден в локальном списке")
                    }
                } else {
                    print("❌ Покупка не найдена в Firebase для урока: \(lessonId)")
                }
            }
        }
    }
    
    func forceUpdateLessonPurchaseStatus(lessonId: String, phone: String) {
        print("🚀 Принудительное обновление статуса покупки для урока: \(lessonId)")
        
        // Сначала проверяем в Firebase
        databaseRef.child("videoLessonPurchases").child(phone).queryOrdered(byChild: "videoLessonId").queryEqual(toValue: lessonId).observeSingleEvent(of: .value) { [weak self] snapshot in
            DispatchQueue.main.async {
                let hasPurchase = snapshot.exists()
                print("🔍 Проверка Firebase: покупка \(hasPurchase ? "найдена" : "не найдена")")
                
                // Обновляем локальное состояние
                if let index = self?.videoLessons.firstIndex(where: { $0.id == lessonId }) {
                    let oldStatus = self?.videoLessons[index].isPurchased ?? false
                    self?.videoLessons[index].isPurchased = hasPurchase
                    
                    print("📊 Статус урока \(lessonId):")
                    print("   Было: isPurchased = \(oldStatus)")
                    print("   Стало: isPurchased = \(self?.videoLessons[index].isPurchased ?? false)")
                    
                    // Принудительно обновляем UI
                    self?.objectWillChange.send()
                } else {
                    print("❌ Урок \(lessonId) не найден в локальном списке уроков")
                }
            }
        }
    }
    
    func refreshAllPurchaseStatuses(phone: String) {
        print("🔄 Обновляем статусы всех покупок для телефона: \(phone)")
        print("📊 Текущее количество уроков: \(videoLessons.count)")
        
        databaseRef.child("videoLessonPurchases").child(phone).observeSingleEvent(of: .value) { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var purchaseStatuses: [String: Bool] = [:]
                var purchaseDates: [String: Date] = [:]
                
                if let purchases = snapshot.value as? [String: [String: Any]] {
                    print("📋 Найдено покупок в Firebase: \(purchases.count)")
                    
                    for (purchaseId, purchaseData) in purchases {
                        if let videoLessonId = purchaseData["videoLessonId"] as? String {
                            purchaseStatuses[videoLessonId] = true
                            print("📦 Покупка \(purchaseId) для урока: \(videoLessonId)")
                            
                            if let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                                purchaseDates[videoLessonId] = Date(timeIntervalSince1970: timestamp)
                            }
                        }
                    }
                } else {
                    print("❌ Покупки не найдены в Firebase для телефона: \(phone)")
                }
                
                print("🎯 Обновляем локальное состояние уроков...")
                var updatedCount = 0
                var hasChanges = false
                
                // Обновляем локальное состояние всех уроков
                for (index, lesson) in self.videoLessons.enumerated() {
                    print("🔍 Проверяем урок \(lesson.id): \(lesson.title)")
                    print("   Текущий статус: isPurchased = \(lesson.isPurchased)")
                    
                    if let isPurchased = purchaseStatuses[lesson.id] {
                        print("   ✅ Найдена покупка в Firebase, обновляем статус")
                        
                        // Проверяем, изменился ли статус
                        if self.videoLessons[index].isPurchased != isPurchased {
                            hasChanges = true
                            print("   🔄 Статус изменился с \(self.videoLessons[index].isPurchased) на \(isPurchased)")
                        }
                        
                        self.videoLessons[index].isPurchased = isPurchased
                        if isPurchased {
                            self.videoLessons[index].purchaseDate = purchaseDates[lesson.id]
                        }
                        updatedCount += 1
                        print("   ✅ Обновлен: isPurchased = \(self.videoLessons[index].isPurchased)")
                    } else {
                        print("   ❌ Покупка не найдена в Firebase")
                        // Если покупки нет, но урок помечен как купленный, сбрасываем статус
                        if self.videoLessons[index].isPurchased {
                            hasChanges = true
                            print("   🔄 Сбрасываем статус покупки")
                            self.videoLessons[index].isPurchased = false
                            self.videoLessons[index].purchaseDate = nil
                        }
                    }
                }
                
                print("✅ Обновлены статусы покупок для \(updatedCount) из \(self.videoLessons.count) уроков")
                print("🔄 Изменения в данных: \(hasChanges ? "ДА" : "НЕТ")")
                
                // Принудительно обновляем UI только если были изменения
                if hasChanges {
                    print("🚀 Принудительно обновляем UI")
                    self.objectWillChange.send()
                    
                    // Дополнительное логирование для проверки
                    print("🔄 Проверяем финальное состояние уроков:")
                    for lesson in self.videoLessons {
                        if lesson.isPurchased {
                            print("   ✅ \(lesson.id): \(lesson.title) - КУПЛЕН")
                        }
                    }
                } else {
                    print("ℹ️ Изменений не было, UI не обновляем")
                }
            }
        }
    }
    
    func forceRefreshLessonsWithPurchaseStatus(phone: String) {
        print("🚀 Принудительное обновление уроков с статусами покупок")
        
        // Сначала получаем все покупки
        databaseRef.child("videoLessonPurchases").child(phone).observeSingleEvent(of: .value) { [weak self] purchaseSnapshot in
            guard let self = self else { return }
            
            // Создаем словарь покупок
            var userPurchases: [String: Date] = [:]
            if let purchases = purchaseSnapshot.value as? [String: [String: Any]] {
                for (_, purchaseData) in purchases {
                    if let videoLessonId = purchaseData["videoLessonId"] as? String,
                       let timestamp = purchaseData["purchase_date"] as? TimeInterval {
                        userPurchases[videoLessonId] = Date(timeIntervalSince1970: timestamp)
                    }
                }
            }
            
            print("📋 Найдено покупок: \(userPurchases.count)")
            
            // Теперь загружаем уроки и устанавливаем статусы покупок
            self.databaseRef.child("videoLessons").observeSingleEvent(of: .value) { [weak self] lessonSnapshot in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    var lessons: [VideoLesson] = []
                    
                    if let lessonsDict = lessonSnapshot.value as? [String: [String: Any]] {
                        for (lessonId, lessonData) in lessonsDict {
                            if var lesson = VideoLesson(from: lessonData, id: lessonId) {
                                // Устанавливаем статус покупки
                                lesson.isPurchased = userPurchases[lessonId] != nil
                                if lesson.isPurchased {
                                    lesson.purchaseDate = userPurchases[lessonId]
                                    print("✅ Урок \(lessonId): \(lesson.title) - КУПЛЕН")
                                }
                                lessons.append(lesson)
                            }
                        }
                    }
                    
                    // Обновляем список уроков
                    self.videoLessons = lessons.filter { $0.isActive }
                    
                    print("🔄 Список уроков обновлен: \(self.videoLessons.count) уроков")
                    print("📊 Купленных уроков: \(self.videoLessons.filter { $0.isPurchased }.count)")
                    
                    // Принудительно обновляем UI
                    self.objectWillChange.send()
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
    
    // MARK: - Инициализация
    
    init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Обработчик для обновления статуса покупки
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshPurchaseStatus"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userPhone = notification.userInfo?["userPhone"] as? String,
               let paymentId = notification.userInfo?["paymentId"] as? String {
                print("🔄 Получено уведомление об обновлении статуса покупки: \(paymentId)")
                self?.refreshAllPurchaseStatuses(phone: userPhone)
            }
        }
    }
    
    func debugLessonPurchaseStatus(lessonId: String, phone: String) {
        print("🔍 Отладка статуса покупки для урока: \(lessonId)")
        print("📱 Телефон пользователя: \(phone)")
        
        // Проверяем локальное состояние
        if let lesson = videoLessons.first(where: { $0.id == lessonId }) {
            print("📊 Локальное состояние:")
            print("   ID: \(lesson.id)")
            print("   Название: \(lesson.title)")
            print("   isPurchased: \(lesson.isPurchased)")
            print("   purchaseDate: \(lesson.purchaseDate?.description ?? "nil")")
        } else {
            print("❌ Урок не найден в локальном списке")
        }
        
        // Проверяем Firebase
        databaseRef.child("videoLessonPurchases").child(phone).queryOrdered(byChild: "videoLessonId").queryEqual(toValue: lessonId).observeSingleEvent(of: .value) { snapshot in
            print("🔥 Firebase состояние:")
            if let purchases = snapshot.value as? [String: [String: Any]], !purchases.isEmpty {
                print("   ✅ Покупка найдена в Firebase")
                for (purchaseId, purchaseData) in purchases {
                    print("   Покупка ID: \(purchaseId)")
                    print("   Урок ID: \(purchaseData["videoLessonId"] ?? "nil")")
                    print("   Статус: \(purchaseData["status"] ?? "nil")")
                    print("   Дата: \(purchaseData["purchase_date"] ?? "nil")")
                }
            } else {
                print("   ❌ Покупка не найдена в Firebase")
            }
        }
    }
    
    func testAllLessonsStatus() {
        print("🧪 ТЕСТ: Проверяем состояние всех уроков")
        print("📱 Пользователь: \(UserDefaults.standard.string(forKey: "userPhone") ?? "неизвестно")")
        print("📊 Всего уроков: \(videoLessons.count)")
        
        for (index, lesson) in videoLessons.enumerated() {
            print("   \(index + 1). \(lesson.id): \(lesson.title)")
            print("      isPurchased: \(lesson.isPurchased)")
            print("      purchaseDate: \(lesson.purchaseDate?.description ?? "nil")")
            print("      isActive: \(lesson.isActive)")
        }
        
        // Проверяем Firebase
        let userPhone = UserDefaults.standard.string(forKey: "userPhone") ?? ""
        if !userPhone.isEmpty {
            databaseRef.child("videoLessonPurchases").child(userPhone).observeSingleEvent(of: .value) { snapshot in
                print("🔥 Firebase покупки для \(userPhone):")
                if let purchases = snapshot.value as? [String: [String: Any]] {
                    for (purchaseId, purchaseData) in purchases {
                        let lessonId = purchaseData["videoLessonId"] as? String ?? "неизвестно"
                        let status = purchaseData["status"] as? String ?? "неизвестно"
                        print("   Покупка \(purchaseId): урок \(lessonId), статус \(status)")
                    }
                } else {
                    print("   Покупок не найдено")
                }
            }
        }
    }
}
