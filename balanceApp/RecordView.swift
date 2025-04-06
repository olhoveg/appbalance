import SwiftUI
import Combine
import FirebaseDatabase
import OneSignalFramework

// MARK: - Расширение модели Record

extension Record {
    var lengthValue: Int {
        return length ?? 600  // Если length отсутствует, используем значение по умолчанию
    }
    
    var staff: Staff? { return nil }  // Если Staff у вас находится в другом месте
    
    var asRecordModal: RecordModal {
        return RecordModal(
            company_id: self.company_id,
            date: self.date,
            id: self.id,
            last_change_date: self.last_change_date,
            custom_color: self.custom_color,
            attendance: self.attendance,
            visit_attendance: self.visit_attendance,
            visit_id: self.visit_id,
            length: self.lengthValue,
            services: self.services,
            staff: self.staff
        )
    }
}

// MARK: - Модели данных

struct Record: Identifiable, Codable {
    let company_id: Int
    let date: String
    let id: Int
    let last_change_date: String
    let custom_color: String?
    let attendance: Int?
    let visit_attendance: Int?
    let confirmed: Int?
    let length: Int?
    let services: [Service]?
    let visit_id: Int?

    private enum CodingKeys: String, CodingKey {
        case company_id, date, id, last_change_date, custom_color, attendance, visit_attendance, confirmed, length, services, visit_id
    }
}

struct RecordsResponse: Codable {
    let success: Bool
    let data: [Record]?
    let meta: [String: Int]?
}

struct Client: Identifiable, Codable {
    let id: Int
    let company_id: Int
    let name: String?
    let email: String?
}

struct ClientsResponse: Codable {
    let success: Bool
    let data: ClientsData
}

struct ClientsData: Codable {
    let salon_group_id: Int
    let phone: String
    let clients: [Client]
    let meta: [String]?
}

@MainActor
class RecordViewModel: ObservableObject {
    static let sharedInstance = RecordViewModel()
    
    @Published var phone: String = ""
    @Published var clients: [Client] = []
    @Published var recordsByCompany: [String: [Record]] = [:]
    @Published var isLoading: Bool = false
    @Published var playerId: String = ""
    @Published var selectedRecord: Record?
    @Published var showModal: Bool = false
    @Published var debugLogs: [String] = []  // Для отладки (используется только в пуш-уведомлениях)

    // Счётчик запросов для клиентов, чтобы понять, когда все записи загружены
    private var pendingClientRequests: Int = 0
    // Флаг для фиксации любой ошибки во время загрузки
    private var fetchHadError: Bool = false

    // Временное хранилище для записей (используется только во время одного обновления)
    private var tempRecordsByCompany: [String: [Record]] = [:]

    // Словарь для сохранения mapping: [external_id: oneSignalNotificationID]
    var scheduledNotificationMapping: [String: String] {
        get {
            return UserDefaults.standard.dictionary(forKey: "scheduledNotificationMapping") as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "scheduledNotificationMapping")
        }
    }
    
    // Словарь для хранения external_id для каждой записи.
    // Ключ – record.id (как строка), значение – "externalId|lastChangeDate"
    var externalIdMapping: [String: String] {
        get {
            return UserDefaults.standard.dictionary(forKey: "externalIdMapping") as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "externalIdMapping")
        }
    }
    
    // MARK: - Логирование (оставляем только для пуш-уведомлений)
    func log(_ message: String) {
        debugLogs.append(message)
        print(message)
    }
    
    // MARK: - Очистка «битых» уведомлений (пустых notificationId)
    func cleanupEmptyNotifications() {
        var mapping = self.scheduledNotificationMapping
        for (externalId, notifId) in mapping {
            if notifId.isEmpty {
                mapping.removeValue(forKey: externalId)
            }
        }
        self.scheduledNotificationMapping = mapping
    }
    
    // MARK: - Методы работы с external_id для записи
    func getExternalIdMapping() -> [String: (externalId: String, lastChangeDate: String)] {
        var mapping: [String: (externalId: String, lastChangeDate: String)] = [:]
        for (key, value) in self.externalIdMapping {
            let components = value.split(separator: "|")
            if components.count == 2 {
                mapping[key] = (externalId: String(components[0]), lastChangeDate: String(components[1]))
            }
        }
        return mapping
    }
    
    func setExternalIdMapping(_ mapping: [String: (externalId: String, lastChangeDate: String)]) {
        var dict: [String: String] = [:]
        for (key, tuple) in mapping {
            dict[key] = "\(tuple.externalId)|\(tuple.lastChangeDate)"
        }
        self.externalIdMapping = dict
    }
    
    /// Возвращает стабильный external_id для записи. Если запись не изменилась (last_change_date не поменялся) – возвращается сохранённое значение.
    /// Если поменялся `last_change_date` — генерируем новое `externalId`.
    func externalIdForRecord(_ record: Record) -> String {
        var mapping = getExternalIdMapping()
        let recordKey = "\(record.id)"
        if let entry = mapping[recordKey] {
            if entry.lastChangeDate == record.last_change_date {
                return entry.externalId
            } else {
                let newExternalId = UUID().uuidString
                mapping[recordKey] = (externalId: newExternalId, lastChangeDate: record.last_change_date)
                setExternalIdMapping(mapping)
                return newExternalId
            }
        } else {
            let newExternalId = UUID().uuidString
            mapping[recordKey] = (externalId: newExternalId, lastChangeDate: record.last_change_date)
            setExternalIdMapping(mapping)
            return newExternalId
        }
    }
    
    // MARK: - Проверка, есть ли действительно запланированное уведомление
    func isNotificationScheduled(for externalId: String) -> Bool {
        guard let storedId = self.scheduledNotificationMapping[externalId] else {
            return false
        }
        return !storedId.isEmpty
    }
    
    // MARK: - Получение номера телефона и playerId
    func getPhoneNumber() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn, let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            self.phone = savedPhone
        }
        
        if let storedPlayerId = UserDefaults.standard.string(forKey: "OneSignalPlayerID") {
            self.playerId = storedPlayerId
        }
    }
    
    // MARK: - Обновление данных
    func refreshData() {
        getPhoneNumber()
        if self.phone.isEmpty {
            return
        }
        cleanupEmptyNotifications()
        fetchHadError = false
        tempRecordsByCompany.removeAll()
        fetchClients()
    }
    
    // MARK: - Запрос клиентов
    func fetchClients() {
        guard !self.phone.isEmpty else {
            fetchHadError = true
            return
        }
        self.isLoading = true
        let baseApiUrl = "https://api.yclients.com/api/v1/group/415038/clients/"
        guard let url = URL(string: "\(baseApiUrl)?phone=\(self.phone)") else {
            self.isLoading = false
            fetchHadError = true
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                self.isLoading = false
                if error != nil {
                    self.fetchHadError = true
                    return
                }
                guard let data = data else {
                    self.fetchHadError = true
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(ClientsResponse.self, from: data)
                    self.clients = decoded.data.clients
                    
                    self.pendingClientRequests = self.clients.count
                    if self.pendingClientRequests == 0 {
                        self.finishFetchingRecords()
                    } else {
                        for client in self.clients {
                            self.fetchClientRecords(companyId: client.company_id, clientId: client.id)
                        }
                    }
                } catch {
                    self.fetchHadError = true
                }
            }
        }.resume()
    }
    
    func fetchClientRecords(companyId: Int, clientId: Int) {
        self.isLoading = true
        guard let url = URL(string: "https://api.yclients.com/api/v1/records/\(companyId)?client_id=\(clientId)") else {
            self.isLoading = false
            fetchHadError = true
            self.pendingClientRequests -= 1
            if self.pendingClientRequests == 0 {
                self.finishFetchingRecords()
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                self.isLoading = false
                if error != nil {
                    self.fetchHadError = true
                    self.pendingClientRequests -= 1
                    if self.pendingClientRequests == 0 {
                        self.finishFetchingRecords()
                    }
                    return
                }
                guard let data = data else {
                    self.fetchHadError = true
                    self.pendingClientRequests -= 1
                    if self.pendingClientRequests == 0 {
                        self.finishFetchingRecords()
                    }
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(RecordsResponse.self, from: data)
                    let records = decoded.data ?? []
                    self.tempRecordsByCompany["\(companyId)"] = records
                    
                    self.scheduleNotificationsForRecords(records: records)
                    
                } catch {
                    self.fetchHadError = true
                }
                
                self.pendingClientRequests -= 1
                if self.pendingClientRequests == 0 {
                    self.finishFetchingRecords()
                }
            }
        }.resume()
    }
    
    // MARK: - Завершение загрузки
    private func finishFetchingRecords() {
        if !fetchHadError {
            let oldRecordsByCompany = self.recordsByCompany
            let newRecordsByCompany = self.tempRecordsByCompany
            self.checkForChangedRecords(oldRecordsByCompany: oldRecordsByCompany,
                                        newRecordsByCompany: newRecordsByCompany)
            self.recordsByCompany = newRecordsByCompany
            self.checkForDeletedRecords()
        }
    }
    
    
    func sendRecordAddedNotification(record: Record) {
        guard !self.playerId.isEmpty else {
            log("❌ playerId пуст — невозможно отправить уведомление о новой записи.")
            return
        }

        let address = companyIdToAddress["\(record.company_id)"] ?? ""
        let notificationContent = "Добавлена новая запись \(record.id). Время: \(record.date)"

        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else {
            log("❌ Неверный URL для OneSignal API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [self.playerId],
            "external_id": UUID().uuidString,   // Всегда новый external_id
            "collapse_id": UUID().uuidString,   // Всегда новый collapse_id
            "contents": [
                "en": notificationContent,
                "ru": notificationContent
            ],
            "data": [
                "record_id": record.id,
                "address": address,
                "new_record": true
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            // Логируем тело запроса
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                log("📤 JSON в OneSignal (новая запись):\n\(jsonString)")
            }

        } catch {
            log("❌ Ошибка сериализации данных: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    self.log("❌ Ошибка отправки пуша о новой записи: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.log("❌ Нет HTTP-ответа от OneSignal при новой записи")
                    return
                }

                self.log("✅ Пуш о новой записи отправлен, HTTP-ответ: \(httpResponse.statusCode)")

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("📥 Ответ OneSignal (новая запись): \(responseString)")
                }
            }
        }.resume()
    }

    

    // MARK: - Проверка изменившихся записей по last_change_date
    private func checkForChangedRecords(oldRecordsByCompany: [String: [Record]],
                                        newRecordsByCompany: [String: [Record]]) {
        let oldRecordsAll = oldRecordsByCompany.values.flatMap { $0 }
        let oldRecordsMap = Dictionary(uniqueKeysWithValues: oldRecordsAll.map { ($0.id, $0) })
        let newRecordsAll = newRecordsByCompany.values.flatMap { $0 }
        
        for newRecord in newRecordsAll {
            if let oldRecord = oldRecordsMap[newRecord.id] {
                // Существующая запись изменилась
                if oldRecord.last_change_date != newRecord.last_change_date {
                    self.log("🔄 Запись \(newRecord.id) изменилась. Отправляем пуш.")
                    self.sendRecordChangedNotification(record: newRecord)
                }
            } else {
                // 🔥 Новая запись обнаружена
                self.log("🆕 Новая запись \(newRecord.id) добавлена. Отправляем пуш.")
                self.sendRecordAddedNotification(record: newRecord)
            }
        }
    }

    
    // MARK: - Отправка отдельного пуша «Запись изменилась»
    func sendRecordChangedNotification(record: Record) {
        guard !self.playerId.isEmpty else {
            log("❌ playerId пуст — невозможно отправить уведомление.")
            return
        }

        let address = companyIdToAddress["\(record.company_id)"] ?? ""
        let notificationContent = "Запись \(record.id) изменилась. Новое время: \(record.date)"

        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else {
            log("❌ Неверный URL для OneSignal API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")

        // Гарантированно уникальные идентификаторы для каждого уведомления
        let externalId = UUID().uuidString
        let collapseId = UUID().uuidString

        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [self.playerId],
            "external_id": externalId,     // Всегда новый
            "collapse_id": collapseId,     // Всегда новый
            "contents": [
                "en": notificationContent,
                "ru": notificationContent
            ],
            "data": [
                "record_id": record.id,
                "address": address
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            // Логируем тело
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                log("📤 JSON в OneSignal:\n\(jsonString)")
            }

        } catch {
            log("❌ Ошибка сериализации данных: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    self.log("❌ Ошибка отправки пуша: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.log("❌ Нет HTTP-ответа от OneSignal")
                    return
                }

                self.log("✅ Пуш отправлен, HTTP-ответ: \(httpResponse.statusCode)")

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("📥 Ответ OneSignal: \(responseString)")
                }
            }
        }.resume()
    }

    func sendRecordDeletedNotification(recordId: String) {
        guard !self.playerId.isEmpty else {
            log("❌ playerId пуст — невозможно отправить уведомление об удалении.")
            return
        }

        let notificationContent = "Запись \(recordId) была удалена. Проверьте расписание."

        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else {
            log("❌ Неверный URL для OneSignal API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [self.playerId],
            "external_id": UUID().uuidString,   // уникальный external_id
            "collapse_id": UUID().uuidString,   // уникальный collapse_id
            "contents": [
                "en": notificationContent,
                "ru": notificationContent
            ],
            "data": [
                "record_id": recordId,
                "deleted": true
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            // Логируем тело запроса
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                log("📤 JSON в OneSignal (удаление записи):\n\(jsonString)")
            }

        } catch {
            log("❌ Ошибка сериализации данных: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    self.log("❌ Ошибка отправки пуша об удалении: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.log("❌ Нет HTTP-ответа от OneSignal при удалении")
                    return
                }

                self.log("✅ Пуш об удалении отправлен, HTTP-ответ: \(httpResponse.statusCode)")

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("📥 Ответ OneSignal (удаление): \(responseString)")
                }
            }
        }.resume()
    }

    
    
    
    // MARK: - Проверка и отмена уведомлений для удалённых записей
    func checkForDeletedRecords() {
        let allRecords = self.recordsByCompany.values.flatMap { $0 }
        let currentRecordIds = Set(allRecords.map { "\($0.id)" })
        
        let existingMapping = self.getExternalIdMapping()
        var updatedMapping = existingMapping
        
        for (recordId, mappingValue) in existingMapping {
            if !currentRecordIds.contains(recordId) {
                let externalId = mappingValue.externalId
                self.log("Запись id \(recordId) была удалена. Отменяем уведомление (если запланировано).")
                
                // Отменяем запланированное уведомление (если было)
                if let notifId = self.notificationId(for: externalId) {
                    self.cancelNotification(notificationId: notifId, externalId: externalId)
                }

                // 🔥 Добавляем отправку мгновенного пуша об удалении
                self.sendRecordDeletedNotification(recordId: recordId)
                
                updatedMapping.removeValue(forKey: recordId)
            }
        }
        
        self.setExternalIdMapping(updatedMapping)
        self.log("Проверка удалённых записей завершена.")
    }

    
    // MARK: - Запланированные уведомления и их управление
    
    func notificationId(for externalId: String) -> String? {
        self.scheduledNotificationMapping[externalId]
    }
    
    func saveScheduledNotification(notificationId: String, for externalId: String) {
        var mapping = self.scheduledNotificationMapping
        mapping[externalId] = notificationId
        self.scheduledNotificationMapping = mapping
    }
    
    func removeScheduledNotification(for externalId: String) {
        var mapping = self.scheduledNotificationMapping
        mapping.removeValue(forKey: externalId)
        self.scheduledNotificationMapping = mapping
    }
    
    func cancelExistingNotification(for record: Record) {
        let recordId = "\(record.id)"
        let mapping = getExternalIdMapping()
        if let storedEntry = mapping[recordId] {
            let currentExternalId = externalIdForRecord(record)
            if storedEntry.externalId != currentExternalId {
                self.log("Для записи \(record.id) обнаружено старое уведомление с external_id \(storedEntry.externalId). Отменяем его.")
                if let notifId = notificationId(for: storedEntry.externalId) {
                    cancelNotification(notificationId: notifId, externalId: storedEntry.externalId)
                }
            }
        }
    }
    
    func cancelNotification(notificationId: String, externalId: String) {
        let urlString = "https://onesignal.com/api/v1/notifications/\(notificationId)?app_id=\(self.appId)"
        guard let url = URL(string: urlString) else {
            self.log("Неверный URL для отмены уведомления")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    self.log("Ошибка при отмене уведомления: \(error.localizedDescription)")
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.log("Не удалось получить ответ от OneSignal при отмене уведомления")
                    return
                }
                self.log("Уведомление с external_id \(externalId) отменено. Код ответа: \(httpResponse.statusCode)")
                self.removeScheduledNotification(for: externalId)
            }
        }.resume()
    }
    
    // MARK: - Планирование уведомлений
    func scheduleNotificationsForRecords(records: [Record]) {
        for record in records {
            guard let recordDate = recordDate(from: record.date) else {
                continue
            }
            
            if recordDate > Date() && (record.confirmed ?? 0) == 1 {
                cancelExistingNotification(for: record)
                let externalId = externalIdForRecord(record)
                if isNotificationScheduled(for: externalId) {
                    continue
                }
                
                if let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: recordDate) {
                    if oneHourBefore > Date() && !self.playerId.isEmpty {
                        let formattedTime = formattedTime(from: recordDate)
                        let address = self.companyIdToAddress["\(record.company_id)"] ?? ""
                        let sendAfter = formattedSendAfter(from: oneHourBefore)
                        sendNotification(date: record.date,
                                         address: address,
                                         playerId: self.playerId,
                                         formattedTime: formattedTime,
                                         sendAfter: sendAfter,
                                         externalId: externalId)
                    }
                }
            }
        }
    }
    
    // MARK: - Отправка уведомления за 1 час
    func sendNotification(date: String, address: String, playerId: String, formattedTime: String, sendAfter: String, externalId: String) {
        let notificationContent = "У Вас запись на \(address) в \(formattedTime)"
        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else {
            self.log("Неверный URL для OneSignal API")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [playerId],
            "external_id": externalId,
            "collapse_id": UUID().uuidString, // 👈 добавь
            "contents": [
                "en": notificationContent,
                "ru": notificationContent
            ],
            "send_after": sendAfter,
            "data": [
                "date": date,
                "address": address,
                "formattedTime": formattedTime
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            self.log("Ошибка сериализации данных уведомления: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    self.log("Ошибка при отправке уведомления: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.log("Не удалось получить ответ от OneSignal")
                    return
                }
                
                self.log("Уведомление отправлено. Код ответа: \(httpResponse.statusCode)")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("Ответ OneSignal: \(responseString)")
                    
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let notificationId = json["id"] as? String {
                        self.log("Сохранён notification_id: \(notificationId) для external_id: \(externalId)")
                        self.saveScheduledNotification(notificationId: notificationId, for: externalId)
                    }
                } else {
                    self.log("Ответ OneSignal получен, но данные не удалось прочитать")
                }
            }
        }.resume()
    }
    
    // MARK: - Вспомогательные методы для дат
    func recordDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
    
    func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func formattedSendAfter(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'GMT'Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: date)
    }
    
    // MARK: - Методы для интерфейса (списки записей и т. п.)
    func upcomingTenRecords() -> [Record] {
        var upcoming: [Record] = []
        let now = Date()
        for (_, records) in self.recordsByCompany {
            for record in records {
                if let recordDate = self.recordDate(from: record.date), recordDate > now {
                    upcoming.append(record)
                }
            }
        }
        upcoming.sort {
            guard let d1 = self.recordDate(from: $0.date),
                  let d2 = self.recordDate(from: $1.date) else { return false }
            return d1 < d2
        }
        return Array(upcoming.prefix(10))
    }
    
    func closestUpcomingRecord(records: [Record]) -> Record? {
        let now = Date()
        let futureRecords = records.filter {
            if let d = self.recordDate(from: $0.date) {
                return d > now
            }
            return false
        }
        return futureRecords.min {
            guard let d1 = self.recordDate(from: $0.date),
                  let d2 = self.recordDate(from: $1.date) else { return false }
            return d1 < d2
        }
    }
    
    func displayRecord(record: Record) -> (address: String, dateString: String) {
        let address = self.companyIdToAddress["\(record.company_id)"] ?? ""
        guard let date = self.recordDate(from: record.date) else {
            return (address, record.date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM HH:mm"
        let formattedDate = formatter.string(from: date)
        return (address, formattedDate)
    }
    
    // MARK: - Методы для подтверждения и удаления (пример, если нужно)
    func confirmRecord(_ record: Record) {
        guard let url = URL(string: "https://api.yclients.com/api/v1/confirmRecord/\(record.id)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.refreshData()
                }
            }
        }.resume()
    }
    
    func deleteRecord(_ record: Record) {
        guard let url = URL(string: "https://api.yclients.com/api/v1/records/\(record.id)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.refreshData()
                }
            }
        }.resume()
    }
    
    // Сопоставление companyId -> адрес
    let companyIdToAddress: [String: String] = [
        "433675": "Коммунаров 26",
        "672239": "Свердлова 126"
    ]
    
    // Константы OneSignal
    let appId: String = "61e511f4-5929-448d-85f4-e5bf171f0764"
    let restApiKey: String = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"
}

// MARK: - Основной SwiftUI интерфейс

struct RecordView: View {
    @StateObject var viewModel = RecordViewModel.sharedInstance

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                let companyIds = ["433675", "672239"]
                ForEach(companyIds, id: \.self) { companyIdKey in
                    let address = viewModel.companyIdToAddress[companyIdKey] ?? ""
                    let records = viewModel.recordsByCompany[companyIdKey] ?? []
                    let futureRecords = records.filter {
                        if let d = viewModel.recordDate(from: $0.date) {
                            return d > Date()
                        }
                        return false
                    }
                    Group {
                        if futureRecords.isEmpty {
                            NoRecordRow(address: address)
                        } else {
                            if let closestRecord = viewModel.closestUpcomingRecord(records: futureRecords) {
                                let display = viewModel.displayRecord(record: closestRecord)
                                RecordRow(address: display.address,
                                          date: display.dateString,
                                          customColor: closestRecord.custom_color,
                                          visit_attendance: closestRecord.visit_attendance,
                                          attendance: closestRecord.attendance)
                                    .onTapGesture {
                                        viewModel.selectedRecord = closestRecord
                                        viewModel.showModal = true
                                    }
                            } else {
                                NoRecordRow(address: address)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.upcomingTenRecords()) { record in
                        if let date = viewModel.recordDate(from: record.date) {
                            let address = viewModel.companyIdToAddress["\(record.company_id)"] ?? ""
                            UpcomingRecordBlock(date: date, address: address)
                                .onTapGesture {
                                    viewModel.selectedRecord = record
                                    viewModel.showModal = true
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .refreshable {
            viewModel.refreshData()
        }
        .onAppear {
            viewModel.getPhoneNumber()
            viewModel.refreshData()
        }
        .sheet(isPresented: $viewModel.showModal) {
            if let record = viewModel.selectedRecord {
                RecordModalView(record: record.asRecordModal, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Запись с подстановкой специалиста

struct RecordRow: View {
    let address: String
    let date: String
    let customColor: String?
    let visit_attendance: Int?
    let attendance: Int?
    
    @State private var specialistName: String = ""
    @State private var checkmarkUrl: String? = nil
    
    var isConfirmed: Bool {
        (visit_attendance == 2 || attendance == 2)
    }
    
    var backgroundColor: Color {
        if address == "Коммунаров 26" {
            return Color(red: 66/255, green: 141/255, blue: 58/255)
        } else if address == "Свердлова 126" {
            return Color(red: 60/255, green: 103/255, blue: 218/255)
        } else {
            return Color(red: 66/255, green: 141/255, blue: 58/255)
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("Вас ждет на")
                .font(.subheadline)
                .foregroundColor(.white)
            Text(address)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(date)
                .font(.subheadline)
                .foregroundColor(.white)
            if !specialistName.isEmpty {
                Text(specialistName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            Group {
                if isConfirmed, let checkmarkUrl = checkmarkUrl, let url = URL(string: checkmarkUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 25, height: 25)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        )
        .onAppear {
            loadCheckmarkUrl()
            loadSpecialistName()
        }
    }
    
    func loadCheckmarkUrl() {
        let ref = Database.database().reference(withPath: "specialists/checkmarkUrl")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let url = snapshot.value as? String {
                self.checkmarkUrl = url
            }
        }
    }
    
    func loadSpecialistName() {
        guard let customColor = customColor else { return }
        let ref = Database.database().reference(withPath: "specialists")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let specialistsDict = snapshot.value as? [String: Any] {
                for (_, value) in specialistsDict {
                    if let spec = value as? [String: Any],
                       let color = spec["color"] as? String,
                       let name = spec["name"] as? String,
                       color == customColor {
                        self.specialistName = name
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Блок "Нет записей"

struct NoRecordRow: View {
    let address: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Нет записей на")
                .font(.headline)
                .foregroundColor(.black)
            Text(address)
                .font(.headline)
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.9))
        .cornerRadius(12)
    }
}

// MARK: - Горизонтальный блок ближайших записей

struct UpcomingRecordBlock: View {
    let date: Date
    let address: String
    
    var body: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        let weekdays = ["ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]
        let dayOfWeek = weekdays[weekdayIndex]
        
        let monthIndex = calendar.component(.month, from: date) - 1
        let genitiveMonths = ["января", "февраля", "марта",
                              "апреля", "мая", "июня",
                              "июля", "августа", "сентября",
                              "октября", "ноября", "декабря"]
        let monthString = genitiveMonths[monthIndex]
        
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "HH:mm"
            return formatter
        }()
        let timeString = timeFormatter.string(from: date)
        
        let backgroundColor: Color = (address == "Коммунаров 26")
            ? Color(red: 66/255, green: 141/255, blue: 58/255)
            : Color(red: 60/255, green: 103/255, blue: 218/255)
        
        ZStack {
            VStack {
                Spacer()
                Text("\(day)")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                Text(monthString)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                Text(timeString)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
            }
            VStack {
                HStack {
                    Spacer()
                    Text(dayOfWeek)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }
                Spacer()
            }
        }
        .frame(width: 70, height: 70)
        .background(backgroundColor)
        .cornerRadius(10)
    }
}

// MARK: - Окно для отладки логов (при необходимости)

struct DebugLogsView: View {
    let debugLogs: [String]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(debugLogs, id: \.self) { log in
                    Text(log)
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.vertical, 1)
                }
            }
            .padding()
        }
    }
}

// MARK: - Превью

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        RecordView()
    }
}
