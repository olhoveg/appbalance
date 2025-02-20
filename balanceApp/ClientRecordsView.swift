//
//  ClientRecordsView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 20.02.2025.
//

//
//  ClientRecordsView.swift
//  YourApp
//
//  Created by YourName on 20.02.2025.
//

import SwiftUI

// MARK: - Модель записи
struct YRecord: Identifiable {
    let id: String
    let companyId: String
    let date: Date
    let status: String
    let lastChangeDate: Date
    let customColor: String?
    // Дополнительные поля, если нужны (visit_attendance, short_link и т.д.)
}

// Пример, как сопоставлять companyId с адресом
let companyIdToAddress: [String: String] = [
    "433675": "Коммунаров 26",
    "672239": "Свердлова 126"
]

// MARK: - OneSignal REST API
/// Эти ключи возьми из личного кабинета OneSignal.
private let oneSignalAppId = "61e511f4-5929-448d-85f4-e5bf171f0764"
private let oneSignalRestKey = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"  // REST API key

// MARK: - Хранилище ID уведомлений
/// Аналог AsyncStorage из React, но в iOS:
/// Сохраняем массив ID уведомлений в UserDefaults
private func setScheduledNotifications(_ notificationId: String) {
    do {
        var notifications = UserDefaults.standard.stringArray(forKey: "scheduledNotifications") ?? []
        notifications.append(notificationId)
        UserDefaults.standard.set(notifications, forKey: "scheduledNotifications")
        print("ID уведомления успешно сохранен:", notificationId)
    } catch {
        print("Ошибка при сохранении ID уведомления:", error)
    }
}

private func deleteNotificationsFromOneSignal(ids: [String]) async {
    guard !ids.isEmpty else { return }
    // Удаляем каждое уведомление по REST-запросу
    let baseUrl = "https://onesignal.com/api/v1/notifications/"
    for id in ids {
        guard let url = URL(string: baseUrl + id + "?app_id=\(oneSignalAppId)") else { continue }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(oneSignalRestKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Уведомление \(id) успешно удалено.")
            } else {
                print("Ошибка при удалении уведомления \(id):", String(data: data, encoding: .utf8) ?? "")
            }
        } catch {
            print("Ошибка сети при удалении уведомления \(id): \(error)")
        }
    }
    // Чистим UserDefaults
    UserDefaults.standard.removeObject(forKey: "scheduledNotifications")
}

// MARK: - Сеттер для отправки уведомления (аналог sendNotification в React)
/// Отправляем POST на OneSignal для запланированного пуша
/// date - дата записи, address - адрес, playerId - oneSignal userId
private func scheduleNotificationIfNeeded(date: Date,
                                         address: String,
                                         playerId: String,
                                         lastChangeDate: Date)
{
    // Генерируем уникальный ключ для предотвращения повторов
    let recordKey = "\(lastChangeDate.timeIntervalSince1970)_\(address)_\(playerId)"
    // Храним во множестве в оперативной памяти?
    // Для упрощения — просто выводим в консоль. Или можно держать в static Set
    print("Проверка уникальности recordKey:", recordKey)
    
    // Определяем время «за час до»
    var oneHourBefore = date
    oneHourBefore.addTimeInterval(-3600)
    
    let now = Date()
    // Запланировать уведомление, если oneHourBefore ещё не прошёл
    if oneHourBefore > now && !playerId.isEmpty {
        let formattedTime = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        // Формируем запрос
        let apiUrl = "https://onesignal.com/api/v1/notifications"
        guard let url = URL(string: apiUrl) else { return }
        
        // Тело запроса
        let body: [String: Any] = [
            "app_id": oneSignalAppId,
            "include_player_ids": [playerId],
            "headings": ["en": "Напоминание о записи"],
            "contents": ["en": "У вас запись на \(address) в \(formattedTime)"],
            "send_after": ISO8601DateFormatter().string(from: oneHourBefore)
        ]
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Basic \(oneSignalRestKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        // Успех
                        let result = try JSONDecoder().decode(OneSignalCreateResponse.self, from: data)
                        print("Уведомление запланировано, ID =", result.id)
                        setScheduledNotifications(result.id)
                    } else {
                        print("Ошибка при отправке уведомления, статус:", (response as? HTTPURLResponse)?.statusCode ?? -1)
                        print("Ответ:", String(data: data, encoding: .utf8) ?? "")
                    }
                } catch {
                    print("Сетевая ошибка при отправке уведомления:", error)
                }
            }
        } catch {
            print("Ошибка сериализации JSON:", error)
        }
    }
}

// MARK: - Структура ответа OneSignal при создании уведомления
private struct OneSignalCreateResponse: Decodable {
    let id: String
    let recipients: Int
}

// MARK: - Работа с Yclients API
private let yclientsAccessToken = "88fnh8jbmt44er5y28nj"
private let yclientsUserToken   = "9d241fb00061c17a5e2e76a23b214b20"

// Пример запроса к https://api.yclients.com/api/v1/group/415038/clients?phone=...
// и https://api.yclients.com/api/v1/records/{companyId}?client_id={clientId}
private func fetchClients(phone: String) async throws -> [YClient] {
    let baseApiUrl = "https://api.yclients.com/api/v1/group/415038/clients"
    guard var urlComponents = URLComponents(string: baseApiUrl) else {
        throw URLError(.badURL)
    }
    urlComponents.queryItems = [
        URLQueryItem(name: "phone", value: phone)
    ]
    guard let url = urlComponents.url else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(yclientsAccessToken), User \(yclientsUserToken)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        throw NSError(domain: "Yclients", code: status, userInfo: [NSLocalizedDescriptionKey: "Ошибка fetchClients, статус \(status)"])
    }
    let result = try JSONDecoder().decode(YClientsResponse.self, from: data)
    return result.data.clients
}

// Ответ от Yclients (упрощённый)
private struct YClientsResponse: Decodable {
    let data: YClientsData
}

private struct YClientsData: Decodable {
    let clients: [YClient]
}

private struct YClient: Decodable, Identifiable {
    // Для SwiftUI ForEach
    var id: String {
        // Примем, что у клиента есть поле "id" -> String
        return String(_id)
    }
    let _id: Int
    let company_id: Int
    let phone: String?
    // Другие поля...
}

// Записи клиента
/// Пример структуры ответа от Yclients records
private struct YRecordsResponse: Decodable {
    let data: [YRecordRaw]
}

/// Пример "сырой" записи
private struct YRecordRaw: Decodable {
    let id: Int
    let client_id: Int
    let company_id: Int
    let date: String        // В формате ISO8601
    let status: String
    let last_change_date: String
    let custom_color: String?
    // ... другие поля
  
    /// Преобразуем в YRecord
    func toYRecord() -> YRecord? {
        // Парсим date
        guard let dateObj = ISO8601DateFormatter().date(from: date),
              let lastChangeDateObj = ISO8601DateFormatter().date(from: last_change_date) else {
            return nil
        }
        return YRecord(
            id: String(id),
            companyId: String(company_id),
            date: dateObj,
            status: status,
            lastChangeDate: lastChangeDateObj,
            customColor: custom_color
        )
    }
}

// MARK: - Запрос записей (Yclients)
private func fetchClientRecords(companyId: Int, clientId: Int) async throws -> [YRecord] {
    let urlString = "https://api.yclients.com/api/v1/records/\(companyId)?client_id=\(clientId)"
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(yclientsAccessToken), User \(yclientsUserToken)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        throw NSError(domain: "YclientsRecords", code: status, userInfo: [NSLocalizedDescriptionKey: "Ошибка fetchClientRecords, статус \(status)"])
    }
    let raw = try JSONDecoder().decode(YRecordsResponse.self, from: data)
    var results: [YRecord] = []
    for item in raw.data {
        if let r = item.toYRecord() {
            results.append(r)
        }
    }
    return results
}

// MARK: - Главное вью, аналог твоего Record.tsx в React
struct ClientRecordsView: View {
    // Телефон из UserDefaults
    @State private var phone: String = ""
    // Список клиентов
    @State private var clients: [YClient] = []
    // Записи, сгруппированные по companyId
    @State private var recordsByCompany: [String: [YRecord]] = [:]
    // Индикатор загрузки
    @State private var isLoading = false
    // OneSignal playerId (аналог deviceState.userId в React)
    @State private var playerId = ""
    // Для показа детальной записи
    @State private var selectedRecord: YRecord? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Загрузка...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading) {
                            // Для каждой компании отображаем ближайшую запись или "нет записи"
                            ForEach(recordsByCompany.keys.sorted(), id: \.self) { companyId in
                                let records = recordsByCompany[companyId] ?? []
                                let address = companyIdToAddress[companyId] ?? "Неизвестный адрес"
                                if records.isEmpty {
                                    NoRecordItemView(address: address)
                                } else if let closest = findClosestUpcomingRecord(from: records) {
                                    // Есть запись
                                    RecordItemView(
                                        record: closest,
                                        address: address
                                    ) {
                                        // Открываем модалку
                                        selectedRecord = closest
                                    }
                                } else {
                                    // Нет предстоящих
                                    NoRecordItemView(address: address)
                                }
                            }
                            
                            // Горизонтальный список ближайших 10
                            let upcoming = findUpcomingTenRecords(recordsByCompany: recordsByCompany)
                            if !upcoming.isEmpty {
                                UpcomingTenRecordsView(records: upcoming)
                            }
                            
                        }
                        .padding()
                    }
                    .refreshable {
                        await fetchData()
                    }
                }
            }
            .navigationTitle("Записи клиента")
            .sheet(item: $selectedRecord) { record in
                // Модальное окно
                RecordModalView(record: record, onClose: {
                    selectedRecord = nil
                }, onRefresh: {
                    Task { await fetchData() }
                })
            }
        }
        .onAppear {
            // 1. Берём номер телефона из UserDefaults
            phone = UserDefaults.standard.string(forKey: "phone") ?? ""
            // 2. Инициализируем OneSignal или берем playerId.
            //    Для примера возьмем заглушку:
            playerId = "FAKE-PLAYER-ID-12345"
            
            Task {
                await fetchData()
            }
        }
    }
    
    // MARK: - Основная функция запроса данных (аналог fetchData в React)
    private func fetchData() async {
        isLoading = true
        
        // 1. Чистим заранее список уникальных записей
        uniqueRecords.removeAll()
        
        // 2. Удаляем запланированные уведомления в OneSignal
        let notifications = UserDefaults.standard.stringArray(forKey: "scheduledNotifications") ?? []
        if !notifications.isEmpty {
            await deleteNotificationsFromOneSignal(ids: notifications)
        }
        
        // 3. Запрашиваем клиентов
        guard !phone.isEmpty else {
            print("Телефон пустой, нет смысла делать запросы.")
            isLoading = false
            return
        }
        do {
            let fetchedClients = try await fetchClients(phone: phone)
            clients = fetchedClients
            // 4. Для каждого клиента запрашиваем его записи
            var tempRecordsByCompany: [String: [YRecord]] = [:]
            for client in fetchedClients {
                let recs = try await fetchClientRecords(companyId: client.company_id, clientId: Int(client.id) ?? 0)
                let companyIdString = String(client.company_id)
                if tempRecordsByCompany[companyIdString] == nil {
                    tempRecordsByCompany[companyIdString] = []
                }
                tempRecordsByCompany[companyIdString]?.append(contentsOf: recs)
            }
            // 5. Сохраняем
            recordsByCompany = tempRecordsByCompany
            
            // 6. Запускаем логику уведомлений
            scheduleNotificationsIfNeeded(recordsByCompany: recordsByCompany)
            
        } catch {
            print("Ошибка при fetchData:", error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Уведомления
    private func scheduleNotificationsIfNeeded(recordsByCompany: [String: [YRecord]]) {
        let now = Date()
        
        // Для каждой компании найдём ближайшую запись (не отменённую)
        for (companyId, records) in recordsByCompany {
            for record in records {
                if record.status != "cancelled", record.date > now {
                    let address = companyIdToAddress[companyId] ?? "Неизвестный адрес"
                    scheduleNotificationIfNeeded(
                        date: record.date,
                        address: address,
                        playerId: playerId,
                        lastChangeDate: record.lastChangeDate
                    )
                }
            }
        }
    }
    
    // MARK: - Хелперы
    private func findClosestUpcomingRecord(from records: [YRecord]) -> YRecord? {
        let now = Date()
        return records
            .filter { $0.date > now }
            .sorted(by: { $0.date < $1.date })
            .first
    }
    
    private func findUpcomingTenRecords(recordsByCompany: [String: [YRecord]]) -> [YRecord] {
        var upcoming: [YRecord] = []
        let now = Date()
        for recs in recordsByCompany.values {
            let filtered = recs.filter { $0.date > now }
            upcoming.append(contentsOf: filtered)
        }
        upcoming.sort { $0.date < $1.date }
        return Array(upcoming.prefix(10))
    }
}

// MARK: - Для хранения уникальных записей, если нужно предотвратить дубли (как uniqueRecords в React)
fileprivate var uniqueRecords = Set<String>()


// MARK: - Вьюха «Нет записи»
struct NoRecordItemView: View {
    let address: String
    
    var body: some View {
        VStack {
            Text("Нет записи").foregroundColor(.secondary)
            Text(address).font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Вьюха записи
struct RecordItemView: View {
    let record: YRecord
    let address: String
    let onPress: () -> Void
    
    var body: some View {
        Button {
            onPress()
        } label: {
            VStack {
                Text(address).font(.headline)
                Text(record.date, style: .time).font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(record.customColor ?? "gray").opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Горизонтальный список ближайших 10
struct UpcomingTenRecordsView: View {
    let records: [YRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ближайшие 10 записей").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(records) { r in
                        VStack {
                            Text(r.date, style: .date)
                            Text(r.date, style: .time)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Модальное окно с деталями записи
struct RecordModalView: View {
    let record: YRecord
    let onClose: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Детали записи").font(.title2)
                Text("Адрес: \(companyIdToAddress[record.companyId] ?? "Неизвестно")")
                Text("Дата: \(record.date, formatter: dateFormatter)")
                Text("Статус: \(record.status)")
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Закрыть") { onClose() },
                trailing: Button("Обновить") { onRefresh() }
            )
        }
    }
}

// Форматер для показа дат
private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    df.locale = Locale(identifier: "ru_RU")
    return df
}()

// MARK: - Превью
struct ClientRecordsView_Previews: PreviewProvider {
    static var previews: some View {
        ClientRecordsView()
    }
}
