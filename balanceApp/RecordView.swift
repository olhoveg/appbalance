import SwiftUI
import Combine
import FirebaseDatabase
import OneSignalFramework

// MARK: - Расширение модели Record

extension Record {
    var lengthValue: Int {
        return length ?? 600
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
    @Published var debugLogs: [String] = []  // Для отладки
    
    private var pendingClientRequests: Int = 0
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
    
    // Словарь для хранения external_id для каждой записи (ключ – record.id как строка)
    var externalIdMapping: [String: String] {
        get {
            return UserDefaults.standard.dictionary(forKey: "externalIdMapping") as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "externalIdMapping")
        }
    }
    
    // MARK: - Логирование (для отладки)
    func log(_ message: String) {
        debugLogs.append(message)
        print(message)
    }
    
    func clearCachedRecords() {
        self.recordsByCompany = [:]
        self.phone = ""
        UserDefaults.standard.removeObject(forKey: "savedRecords")
    }
    
    func loadSavedRecords() {
        guard let data = UserDefaults.standard.data(forKey: "savedRecords") else { return }
        if let dict = try? JSONDecoder().decode([String: [Record]].self, from: data) {
            self.recordsByCompany = dict
        }
    }
    
    func saveRecords(_ dict: [String: [Record]]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "savedRecords")
        }
    }
    
    func cleanupEmptyNotifications() {
        var mapping = self.scheduledNotificationMapping
        for (externalId, notifId) in mapping {
            if notifId.isEmpty {
                mapping.removeValue(forKey: externalId)
            }
        }
        self.scheduledNotificationMapping = mapping
    }
    
    // MARK: - Методы externalIdMapping
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
    
    func isNotificationScheduled(for externalId: String) -> Bool {
        guard let storedId = self.scheduledNotificationMapping[externalId] else {
            return false
        }
        return !storedId.isEmpty
    }
    
    // MARK: - Получение телефона и playerId
    // Теперь phone не загружается из UserDefaults, а устанавливается из authVM
    func updatePhone(with newPhone: String) {
        self.phone = newPhone
    }
    
    func getPlayerId() {
        if let storedPlayerId = UserDefaults.standard.string(forKey: "OneSignalPlayerID") {
            self.playerId = storedPlayerId
        }
    }
    
    // MARK: - Обновление данных
    func refreshData() {
        if self.phone.isEmpty { return }
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
    
    private func finishFetchingRecords() {
        if !fetchHadError {
            let oldRecordsByCompany = self.recordsByCompany
            let newRecordsByCompany = self.tempRecordsByCompany
            
            let (added, changed, deleted) = detectRecordChanges(
                oldRecordsByCompany: oldRecordsByCompany,
                newRecordsByCompany: newRecordsByCompany
            )
            
            self.log("🔍 Итог сравнения записей:")
            self.log("➕ Новые записи: \(added.count)")
            self.log("✏️ Изменённые записи: \(changed.count)")
            self.log("🗑 Удалённые записи: \(deleted.count)")
            
            self.recordsByCompany = newRecordsByCompany
            self.saveRecords(newRecordsByCompany)
            self.cancelNotificationsForDeletedRecords(deleted)
            
            if !added.isEmpty || !changed.isEmpty || !deleted.isEmpty {
                // Проверим, не просто ли замена записей 1-в-1
                if added.count == deleted.count && changed.isEmpty {
                    log("⚠️ Пропускаем пуш: количество новых и удалённых совпадает, изменений нет")
                } else {
                    log("📣 Обнаружены изменения в расписании, отправляем пуш")
                    sendScheduleUpdatedNotification()
                }
            } else {
                log("✅ Изменений нет — пуш не отправляется")
            }
        }
    }

    
    // MARK: - Выявление изменений
    private func detectRecordChanges(oldRecordsByCompany: [String: [Record]],
                                     newRecordsByCompany: [String: [Record]])
        -> (added: [Record], changed: [Record], deleted: [String])
    {
        let oldAll = oldRecordsByCompany.values.flatMap { $0 }
        let newAll = newRecordsByCompany.values.flatMap { $0 }
        
        let oldMap = Dictionary(uniqueKeysWithValues: oldAll.map { ($0.id, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: newAll.map { ($0.id, $0) })
        
        var added = [Record]()
        var changed = [Record]()
        var deletedIds = [String]()
        
        for newRec in newAll {
            if let oldRec = oldMap[newRec.id] {
                if oldRec.last_change_date != newRec.last_change_date {
                    changed.append(newRec)
                }
            } else {
                added.append(newRec)
            }
        }
        
        for oldRec in oldAll {
            if newMap[oldRec.id] == nil {
                deletedIds.append("\(oldRec.id)")
            }
        }
        
        return (added, changed, deletedIds)
    }
    
    // MARK: - Уведомления
    private func cancelNotificationsForDeletedRecords(_ deletedIds: [String]) {
        var existingMapping = self.getExternalIdMapping()
        for recordId in deletedIds {
            if let tuple = existingMapping[recordId] {
                let externalId = tuple.externalId
                self.log("Запись \(recordId) удалена. Отменяем уведомление.")
                if let notifId = self.notificationId(for: externalId) {
                    self.cancelNotification(notificationId: notifId, externalId: externalId)
                }
                existingMapping.removeValue(forKey: recordId)
            }
        }
        self.setExternalIdMapping(existingMapping)
    }
    
    private func sendScheduleUpdatedNotification() {
        guard !self.playerId.isEmpty, let url = URL(string: "https://onesignal.com/api/v1/notifications") else { return }
        let notificationContent = "Ваше расписание изменилось."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [self.playerId],
            "external_id": UUID().uuidString,
            "collapse_id": UUID().uuidString,
            "contents": [
                "en": notificationContent,
                "ru": notificationContent
            ],
            "data": [
                "schedule_changed": true
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch { return }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                guard error == nil, let httpResponse = response as? HTTPURLResponse else { return }
                self.log("Общий пуш отправлен, код ответа: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("Ответ OneSignal: \(responseString)")
                }
            }
        }.resume()
    }
    
    // MARK: - Работа с уведомлениями
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
            if storedEntry.externalId != currentExternalId,
               let notifId = notificationId(for: storedEntry.externalId) {
                cancelNotification(notificationId: notifId, externalId: storedEntry.externalId)
            }
        }
    }
    
    func cancelNotification(notificationId: String, externalId: String) {
        let urlString = "https://onesignal.com/api/v1/notifications/\(notificationId)?app_id=\(self.appId)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                guard error == nil, let httpResponse = response as? HTTPURLResponse else { return }
                self.log("Уведомление (external_id=\(externalId)) отменено, код ответа: \(httpResponse.statusCode)")
                self.removeScheduledNotification(for: externalId)
            }
        }.resume()
    }
    
    func scheduleNotificationsForRecords(records: [Record]) {
        for record in records {
            guard let recordDate = recordDate(from: record.date) else { continue }
            if recordDate > Date(), (record.confirmed ?? 0) == 1 {
                cancelExistingNotification(for: record)
                let externalId = externalIdForRecord(record)
                if isNotificationScheduled(for: externalId) { continue }
                
                if let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: recordDate),
                   oneHourBefore > Date(), !self.playerId.isEmpty {
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
    
    func sendNotification(date: String,
                          address: String,
                          playerId: String,
                          formattedTime: String,
                          sendAfter: String,
                          externalId: String)
    {
        let notificationContent = "У Вас запись на \(address) в \(formattedTime)"
        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "app_id": self.appId,
            "include_player_ids": [playerId],
            "external_id": externalId,
            "collapse_id": UUID().uuidString,
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
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                guard error == nil, let httpResponse = response as? HTTPURLResponse else { return }
                self.log("Уведомление (за час) отправлено, код ответа: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.log("Ответ OneSignal: \(responseString)")
                }
            }
        }.resume()
    }
    
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
                  let d2 = self.recordDate(from: $1.date)
            else { return false }
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
    
    // MARK: - Пример подтверждения/удаления (если нужно)
    func confirmRecord(_ record: Record) {
        // ...
    }
    
    func deleteRecord(_ record: Record) {
        // ...
    }
    
    let companyIdToAddress: [String: String] = [
        "433675": "Коммунаров 26",
        "672239": "Свердлова 126"
    ]
    
    let appId: String = "61e511f4-5929-448d-85f4-e5bf171f0764"
    let restApiKey: String = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"
}

// MARK: - Пример основного SwiftUI View

struct RecordView: View {
    @StateObject var viewModel = RecordViewModel.sharedInstance
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showLogin = false
        
    var body: some View {
        VStack {
            if authVM.isLoggedIn {
                content
            } else {
                VStack(spacing: 12) {
                    Text("Чтобы просматривать и управлять записями, пожалуйста, авторизуйтесь.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Войти") {
                        showLogin = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginScreen {
                authVM.loginSuccessfully()
                viewModel.phone = authVM.phone
                viewModel.refreshData()
            }
        }
        .onAppear {
            if authVM.isLoggedIn {
                viewModel.phone = authVM.phone
                viewModel.playerId = UserDefaults.standard.string(forKey: "OneSignalPlayerID") ?? ""
                print("📲 onAppear: playerId = \(viewModel.playerId)")
                viewModel.refreshData()
                viewModel.loadSavedRecords()
            }
        }
    }
    
    @ViewBuilder
    var content: some View {
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
            viewModel.phone = authVM.phone
            viewModel.refreshData()
            viewModel.loadSavedRecords()
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
