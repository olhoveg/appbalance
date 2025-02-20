import SwiftUI
import Combine

// MARK: - Модели данных

struct Record: Identifiable, Codable {
    let company_id: String
    let date: String
    let status: String
    let id: String
    let last_change_date: String
    let custom_color: String?
    let attendance: Bool?
    let visit_attendance: Bool?
}

struct Client: Identifiable, Codable {
    let id: String
    let company_id: String
    // Дополнительные поля при необходимости
}

// MARK: - Ответы API

struct ClientsResponse: Codable {
    let data: ClientsData
}

struct ClientsData: Codable {
    let clients: [Client]
}

struct RecordsResponse: Codable {
    let data: [Record]
}

// MARK: - ViewModel

class RecordViewModel: ObservableObject {
    @Published var phone: String = ""
    @Published var clients: [Client] = []
    @Published var recordsByCompany: [String: [Record]] = [:]
    @Published var isLoading: Bool = false
    @Published var playerId: String = ""
    @Published var selectedRecord: Record?
    @Published var showModal: Bool = false

    // Множество для фильтрации дубликатов уведомлений
    var uniqueRecords: Set<String> = Set()
    
    // Константы для OneSignal и API
    let appId = "61e511f4-5929-448d-85f4-e5bf171f0764"
    let restApiKey = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"
    
    let companyIdToAddress: [String: String] = [
        "433675": "Коммунаров 26",
        "672239": "Свердлова 126"
    ]
    
    // Получение номера телефона из UserDefaults (аналог AsyncStorage)
    func getPhoneNumber() {
        if let savedPhone = UserDefaults.standard.string(forKey: "phone") {
            phone = savedPhone
        }
    }
    
    // Обновление данных: сначала получаем клиентов, а затем для каждого клиента – записи
    func refreshData() {
        uniqueRecords.removeAll()
        recordsByCompany.removeAll()
        fetchClients()
    }
    
    // Получение клиентов через API Yclients
    func fetchClients() {
        guard !phone.isEmpty else { return }
        isLoading = true
        let baseApiUrl = "https://api.yclients.com/api/v1/group/415038/clients/"
        guard let url = URL(string: "\(baseApiUrl)?phone=\(phone)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            guard let data = data, error == nil else {
                print("Ошибка получения клиентов: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(ClientsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.clients = decoded.data.clients
                    for client in self.clients {
                        self.fetchClientRecords(companyId: client.company_id, clientId: client.id)
                    }
                }
            } catch {
                print("Ошибка декодирования клиентов: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // Получение записей для конкретного клиента
    func fetchClientRecords(companyId: String, clientId: String) {
        isLoading = true
        guard let url = URL(string: "https://api.yclients.com/api/v1/records/\(companyId)?client_id=\(clientId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            guard let data = data, error == nil else {
                print("Ошибка получения записей: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(RecordsResponse.self, from: data)
                DispatchQueue.main.async {
                    let records = decoded.data
                    self.recordsByCompany[companyId] = records
                    // После получения записей – планируем уведомления
                    self.scheduleNotificationsForRecords(records: records)
                }
            } catch {
                print("Ошибка декодирования записей: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // Планирование уведомлений для полученных записей
    func scheduleNotificationsForRecords(records: [Record]) {
        let now = Date()
        for record in records {
            guard let recordDate = ISO8601DateFormatter().date(from: record.date) else { continue }
            if recordDate > now && record.status != "cancelled" {
                let recordKey = "\(record.last_change_date)_\(record.company_id)_\(playerId)_\(record.last_change_date)"
                if uniqueRecords.contains(recordKey) {
                    print("Пропуск дубликата записи: \(recordKey)")
                    continue
                }
                uniqueRecords.insert(recordKey)
                
                // Уведомление за час до записи
                if let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: recordDate),
                   oneHourBefore > now, !playerId.isEmpty {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "ru_RU")
                    formatter.dateFormat = "HH:mm"
                    let formattedTime = formatter.string(from: recordDate)
                    let address = companyIdToAddress[record.company_id] ?? ""
                    sendNotification(date: record.date, address: address, playerId: playerId, formattedTime: formattedTime)
                }
            }
        }
    }
    
    // Функция отправки уведомления через OneSignal API (здесь – только демонстрация)
    func sendNotification(date: String, address: String, playerId: String, formattedTime: String) {
        // Реализуйте вызов OneSignal API или вызов локального планирования уведомлений
        print("Отправка уведомления: У Вас запись на \(address) в \(formattedTime)")
    }
    
    // Получение ближайших 10 предстоящих записей
    func upcomingTenRecords() -> [Record] {
        var upcoming: [Record] = []
        let now = Date()
        for (_, records) in recordsByCompany {
            for record in records {
                if let recordDate = ISO8601DateFormatter().date(from: record.date), recordDate > now {
                    upcoming.append(record)
                }
            }
        }
        upcoming.sort {
            guard let date1 = ISO8601DateFormatter().date(from: $0.date),
                  let date2 = ISO8601DateFormatter().date(from: $1.date) else { return false }
            return date1 < date2
        }
        return Array(upcoming.prefix(10))
    }
    
    // Нахождение ближайшей записи для конкретного набора записей
    func closestUpcomingRecord(records: [Record]) -> Record? {
        let now = Date()
        return records.filter {
            if let date = ISO8601DateFormatter().date(from: $0.date) {
                return date > now
            }
            return false
        }.min(by: {
            guard let date1 = ISO8601DateFormatter().date(from: $0.date),
                  let date2 = ISO8601DateFormatter().date(from: $1.date) else { return false }
            return date1 < date2
        })
    }
    
    // Форматирование записи для отображения
    func displayRecord(record: Record) -> (address: String, dateString: String) {
        let address = companyIdToAddress[record.company_id] ?? ""
        guard let date = ISO8601DateFormatter().date(from: record.date) else {
            return (address, record.date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM HH:mm"
        let formattedDate = formatter.string(from: date)
        return (address, formattedDate)
    }
    
    // Вспомогательный метод для получения месяца в родительном падеже
    func getRussianMonth(for date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let genitiveMonths = [
            "января", "февраля", "марта", "апреля", "мая", "июня",
            "июля", "августа", "сентября", "октября", "ноября", "декабря"
        ]
        return genitiveMonths[month - 1]
    }
}

// MARK: - Основной SwiftUI интерфейс

struct RecordView: View {
    @StateObject var viewModel = RecordViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Список записей по филиалам
                    ForEach(viewModel.recordsByCompany.keys.sorted(), id: \.self) { companyId in
                        if let records = viewModel.recordsByCompany[companyId] {
                            let address = viewModel.companyIdToAddress[companyId] ?? ""
                            if let closestRecord = viewModel.closestUpcomingRecord(records: records) {
                                let display = viewModel.displayRecord(record: closestRecord)
                                RecordRow(address: display.address, date: display.dateString)
                                    .onTapGesture {
                                        viewModel.selectedRecord = closestRecord
                                        viewModel.showModal = true
                                    }
                            } else {
                                NoRecordRow(address: address)
                            }
                        }
                    }
                    
                    // Горизонтальная лента с 10 предстоящими записями
                    UpcomingTenRecordsView(records: viewModel.upcomingTenRecords(), viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Записи")
            .toolbar {
                Button(action: {
                    viewModel.refreshData()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            // iOS 15+ поддержка pull-to-refresh
            .refreshable {
                viewModel.refreshData()
            }
            .onAppear {
                viewModel.getPhoneNumber()
                viewModel.refreshData()
                // Здесь можно добавить получение playerId через OneSignal
            }
            .sheet(isPresented: $viewModel.showModal) {
                if let record = viewModel.selectedRecord {
                    RecordModalView(record: record, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Отдельные View

struct RecordRow: View {
    let address: String
    let date: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(address)
                    .font(.headline)
                Text(date)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }
}

struct NoRecordRow: View {
    let address: String
    var body: some View {
        HStack {
            Text("Нет записи для \(address)")
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct UpcomingTenRecordsView: View {
    let records: [Record]
    let viewModel: RecordViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(records) { record in
                    if let date = ISO8601DateFormatter().date(from: record.date) {
                        UpcomingRecordBlock(date: date, address: viewModel.companyIdToAddress[record.company_id] ?? "", viewModel: viewModel)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct UpcomingRecordBlock: View {
    let date: Date
    let address: String
    let viewModel: RecordViewModel
    
    var body: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1 // В Swift воскресенье = 1
        let weekdays = ["ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]
        let dayOfWeek = weekdays[weekdayIndex]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        // Выбор цвета фона на основании адреса
        let backgroundColor: Color = (address == "Коммунаров 26") ? Color(red: 66/255, green: 141/255, blue: 58/255) : Color(red: 60/255, green: 103/255, blue: 218/255)
        
        return VStack {
            Text(dayOfWeek)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.top, 4)
            Text("\(day)")
                .font(.title)
                .foregroundColor(.white)
            Text(time)
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 60)
        .background(backgroundColor)
        .cornerRadius(10)
    }
}

struct RecordModalView: View {
    let record: Record
    @ObservedObject var viewModel: RecordViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Детали записи")
                .font(.title)
                .padding()
            Text("ID: \(record.id)")
            Text("Дата: \(record.date)")
            Text("Статус: \(record.status)")
            // Можно добавить дополнительные данные о записи
            Button("Закрыть") {
                viewModel.showModal = false
            }
        }
        .padding()
    }
}

// MARK: - Превью

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        RecordView()
    }
}
