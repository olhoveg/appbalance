//
//  RecordView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 12.02.2025.
//

import SwiftUI
import Combine
import FirebaseDatabase
import OneSignalFramework

// MARK: - Расширение модели Record

extension Record {
    var lengthValue: Int {
        return length ?? 600  // Если length отсутствует, используем значение по умолчанию
    }
    
    var staff: Staff? { return nil }
    
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

// MARK: - RecordViewModel с логикой уведомлений

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
    
    // Константы OneSignal и сопоставление адресов
    let appId: String = "61e511f4-5929-448d-85f4-e5bf171f0764"
    let restApiKey: String = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"
    let companyIdToAddress: [String: String] = [
        "433675": "Коммунаров 26",
        "672239": "Свердлова 126"
    ]
    
    // MARK: - Логирование
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.debugLogs.append(message)
        }
        print(message)
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
    
    // MARK: - Получение номера телефона и playerId
    func getPhoneNumber() {
        log("Получение номера телефона из UserDefaults")
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn, let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            self.phone = savedPhone
            log("Найден сохраненный телефон: \(savedPhone)")
        } else {
            log("Пользователь не авторизован или телефон не найден")
        }
        
        if let storedPlayerId = UserDefaults.standard.string(forKey: "OneSignalPlayerID") {
            self.playerId = storedPlayerId
            log("Получен playerId: \(storedPlayerId)")
        } else {
            log("playerId не найден в UserDefaults")
        }
    }
    
    // MARK: - Обновление данных
    func refreshData() {
        getPhoneNumber()
        log("Начало обновления данных")
        // Не очищаем externalIdMapping, чтобы сохранить историю для сравнения
        self.recordsByCompany.removeAll()
        self.fetchClients()
    }
    
    // MARK: - Запрос клиентов
    func fetchClients() {
        guard !self.phone.isEmpty else {
            log("Номер телефона пустой, невозможно получить клиентов")
            return
        }
        self.isLoading = true
        log("Запрос клиентов для телефона: \(self.phone)")
        
        let baseApiUrl = "https://api.yclients.com/api/v1/group/415038/clients/"
        guard let url = URL(string: "\(baseApiUrl)?phone=\(self.phone)") else {
            log("Неверный URL для клиентов")
            self.isLoading = false
            return
        }
        log("Сформированный URL для клиентов: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
            if let error = error {
                self.log("Ошибка получения клиентов: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                self.log("Данные клиентов не получены")
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                self.log("Сырой JSON-ответ от API для клиентов:\n\(jsonString)")
            } else {
                self.log("Невозможно преобразовать данные клиентов в строку")
            }
            
            do {
                let decoded = try JSONDecoder().decode(ClientsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.clients = decoded.data.clients
                    self.log("Получены клиенты: \(self.clients.map { String($0.id) }.joined(separator: ", "))")
                    for client in self.clients {
                        self.fetchClientRecords(companyId: client.company_id, clientId: client.id)
                    }
                }
            } catch {
                self.log("Ошибка декодирования клиентов: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func fetchClientRecords(companyId: Int, clientId: Int) {
        self.isLoading = true
        log("Начало запроса записей для companyId: \(companyId), clientId: \(clientId)")
        guard let url = URL(string: "https://api.yclients.com/api/v1/records/\(companyId)?client_id=\(clientId)") else {
            log("Неверный URL для записей")
            self.isLoading = false
            return
        }
        log("Сформированный URL для записей: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
            if let error = error {
                self.log("Ошибка получения записей: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                self.log("Данные записей не получены")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.log("Ответ сервера для записей: статус \(httpResponse.statusCode)")
                self.log("Заголовки: \(httpResponse.allHeaderFields)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                self.log("Сырой JSON-ответ от API для записей:\n\(jsonString)")
            } else {
                self.log("Невозможно преобразовать данные записей в строку")
            }
            
            do {
                let decoded = try JSONDecoder().decode(RecordsResponse.self, from: data)
                DispatchQueue.main.async {
                    let records = decoded.data ?? []
                    self.recordsByCompany["\(companyId)"] = records
                    self.log("Получены записи для companyId \(companyId): \(records.map { String($0.id) }.joined(separator: ", "))")
                    self.scheduleNotificationsForRecords(records: records)
                }
            } catch {
                self.log("Ошибка декодирования записей: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Вспомогательная функция для форматирования даты для send_after
    func formattedSendAfter(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'GMT'Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: date)
    }
    
    // MARK: - Методы работы с запланированными уведомлениями
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
    
    func notificationId(for externalId: String) -> String? {
        return self.scheduledNotificationMapping[externalId]
    }
    
    func isNotificationScheduled(for externalId: String) -> Bool {
        return self.scheduledNotificationMapping.keys.contains(externalId)
    }
    
    // MARK: - Отмена уведомлений (отменяем старое только если запись изменилась)
    func cancelExistingNotification(for record: Record) {
        let recordId = "\(record.id)"
        // Получаем сохранённое external_id для этой записи
        let mapping = getExternalIdMapping()
        if let storedEntry = mapping[recordId] {
            let currentExternalId = externalIdForRecord(record)
            if storedEntry.externalId != currentExternalId {
                // Если external_id изменился, значит запись изменилась – отменяем старое уведомление
                if let notifId = notificationId(for: storedEntry.externalId) {
                    log("Для записи \(record.id) обнаружено старое уведомление с external_id \(storedEntry.externalId). Отменяем его.")
                    cancelNotification(notificationId: notifId, externalId: storedEntry.externalId)
                }
            }
        }
    }
    
    func cancelNotification(notificationId: String, externalId: String) {
        let urlString = "https://onesignal.com/api/v1/notifications/\(notificationId)?app_id=\(self.appId)"
        guard let url = URL(string: urlString) else {
            log("Неверный URL для отмены уведомления")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Basic \(self.restApiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
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
    
    // MARK: - Планирование уведомлений с учетом отмены старых при изменении записи
    func scheduleNotificationsForRecords(records: [Record]) {
        log("Начало планирования уведомлений для \(records.count) записей")
        let now = Date()
        for record in records {
            log("Обработка записи id: \(record.id), дата: \(record.date)")
            guard let recordDate = recordDate(from: record.date) else {
                log("Невозможно преобразовать дату \(record.date) для записи id: \(record.id)")
                continue
            }
            if recordDate > now && (record.confirmed ?? 0) == 1 {
                // Отменяем старое уведомление только если запись изменилась
                cancelExistingNotification(for: record)
                
                let externalId = externalIdForRecord(record)
                if isNotificationScheduled(for: externalId) {
                    log("Уведомление для записи \(record.id) уже запланировано")
                    continue
                }
                
                if let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: recordDate) {
                    log("Вычислено время за час до записи для id \(record.id): \(oneHourBefore)")
                    if oneHourBefore > now && !self.playerId.isEmpty {
                        let formattedTime = formattedTime(from: recordDate)
                        let address = self.companyIdToAddress["\(record.company_id)"] ?? ""
                        let sendAfter = formattedSendAfter(from: oneHourBefore)
                        log("Планирование уведомления для записи id \(record.id) с send_after: \(sendAfter)")
                        
                        // Сохраняем external_id (notification_id обновится после ответа)
                        saveScheduledNotification(notificationId: "", for: externalId)
                        
                        sendNotification(date: record.date,
                                         address: address,
                                         playerId: self.playerId,
                                         formattedTime: formattedTime,
                                         sendAfter: sendAfter,
                                         externalId: externalId)
                    } else {
                        log("Условия не выполнены для записи \(record.id): oneHourBefore (\(oneHourBefore)) <= now (\(now)) или playerId пуст")
                    }
                } else {
                    log("Не удалось вычислить oneHourBefore для записи \(record.id)")
                }
            } else {
                log("Запись \(record.id) не актуальна или не подтверждена (confirmed: \(record.confirmed ?? 0))")
            }
        }
        log("Завершено планирование уведомлений для записей")
    }
    
    // MARK: - Отправка уведомления с external_id
    func sendNotification(date: String, address: String, playerId: String, formattedTime: String, sendAfter: String, externalId: String) {
        let notificationContent = "У Вас запись на \(address) в \(formattedTime)"
        log("Подготовка уведомления: \(notificationContent) для playerId: \(playerId)")
        
        guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else {
            log("Неверный URL для OneSignal API")
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
            log("Ошибка сериализации данных уведомления: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
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
    
    // MARK: - Вспомогательные методы для работы с датами
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
    
    // MARK: - Методы для интерфейса
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
            log("Невозможно преобразовать дату \(record.date) для записи \(record.id)")
            return (address, record.date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM HH:mm"
        let formattedDate = formatter.string(from: date)
        return (address, formattedDate)
    }
}

// MARK: - Основной SwiftUI интерфейс

struct RecordView: View {
    @StateObject var viewModel = RecordViewModel.sharedInstance

    var body: some View {
        // Убираем NavigationView и navigationTitle
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
                                        _ = viewModel.log("Открытие модального окна для записи \(closestRecord.id)")
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

// MARK: - Окно для отладки логов

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
