import SwiftUI
import Combine
import FirebaseDatabase


extension Record {
    // Удалите или закомментируйте эту строку:
    // var visit_id: Int? { return nil }
    
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
            visit_id: self.visit_id, // теперь будет использовать значение, декодированное из JSON
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
    let visit_id: Int?  // Добавлено, чтобы декодировалось из JSON

    private enum CodingKeys: String, CodingKey {
        case company_id, date, id, last_change_date, custom_color, attendance, visit_attendance, confirmed, length, services, visit_id
    }
}

struct RecordsResponse: Codable {
    let success: Bool
    let data: [Record]?
    let meta: [String: Int]?  // Например: page, total_count
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

// MARK: - ViewModel с отладкой

class RecordViewModel: ObservableObject {
    @Published var phone: String = ""
    @Published var clients: [Client] = []
    // Словарь: ключ – строковое представление company_id, значение – массив записей
    @Published var recordsByCompany: [String: [Record]] = [:]
    @Published var isLoading: Bool = false
    @Published var playerId: String = ""
    @Published var selectedRecord: Record?
    @Published var showModal: Bool = false
    @Published var debugLogs: [String] = []  // Для отладки

    var uniqueRecords: Set<String> = Set()
    
    // Константы OneSignal (если нужны)
    let appId = "61e511f4-5929-448d-85f4-e5bf171f0764"
    let restApiKey = "ZjRjZTA1NjgtZDNhMS00ZWNkLWIwZjQtYzkwMWI2MThmOTQ2"
    
    // Преобразуем числовой company_id в строку для словаря адресов
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
    
    // MARK: - Получение номера телефона
    func getPhoneNumber() {
        log("Получение номера телефона из UserDefaults")
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn, let savedPhone = UserDefaults.standard.string(forKey: "userPhone") {
            phone = savedPhone
            log("Найден сохраненный телефон: \(savedPhone)")
        } else {
            log("Пользователь не авторизован или телефон не найден")
        }
    }
    
    // MARK: - Обновление данных
    func refreshData() {
        log("Начало обновления данных")
        uniqueRecords.removeAll()
        recordsByCompany.removeAll()
        fetchClients()
    }
    
    // MARK: - Запрос клиентов
    func fetchClients() {
        guard !phone.isEmpty else {
            log("Номер телефона пустой, невозможно получить клиентов")
            return
        }
        isLoading = true
        log("Запрос клиентов для телефона: \(phone)")
        
        let baseApiUrl = "https://api.yclients.com/api/v1/group/415038/clients/"
        guard let url = URL(string: "\(baseApiUrl)?phone=\(phone)") else {
            log("Неверный URL для клиентов")
            isLoading = false
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
    
    // MARK: - Запрос записей для конкретного клиента
    func fetchClientRecords(companyId: Int, clientId: Int) {
        isLoading = true
        log("Начало запроса записей для companyId: \(companyId), clientId: \(clientId)")
        guard let url = URL(string: "https://api.yclients.com/api/v1/records/\(companyId)?client_id=\(clientId)") else {
            log("Неверный URL для записей")
            isLoading = false
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
                    self.recordsByCompany[String(companyId)] = records
                    self.log("Получены записи для companyId \(companyId): \(records.map { String($0.id) }.joined(separator: ", "))")
                    self.scheduleNotificationsForRecords(records: records)
                }
            } catch {
                self.log("Ошибка декодирования записей: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Планирование уведомлений (пример логики)
    func scheduleNotificationsForRecords(records: [Record]) {
        log("Начало планирования уведомлений для \(records.count) записей")
        let now = Date()
        for record in records {
            log("Обработка записи id: \(record.id), дата: \(record.date)")
            guard let recordDate = recordDate(from: record.date) else {
                log("Невозможно преобразовать дату \(record.date) для записи id: \(record.id)")
                continue
            }
            // Пример: показываем только записи, подтверждённые (confirmed == 1)
            if recordDate > now && (record.confirmed ?? 0) == 1 {
                let recordKey = "\(record.last_change_date)_\(record.company_id)_\(playerId)_\(record.last_change_date)"
                if uniqueRecords.contains(recordKey) {
                    log("Пропуск дубликата записи: \(recordKey)")
                    continue
                }
                uniqueRecords.insert(recordKey)
                
                if let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: recordDate) {
                    log("Вычисленное время (за час до записи): \(oneHourBefore)")
                    if oneHourBefore > now && !playerId.isEmpty {
                        let formattedTime = formattedTime(from: recordDate)
                        let address = companyIdToAddress[String(record.company_id)] ?? ""
                        sendNotification(date: record.date, address: address, playerId: playerId, formattedTime: formattedTime)
                    } else {
                        log("Условия для уведомления не выполнены для записи \(record.id): oneHourBefore (\(oneHourBefore)) <= now (\(now)) или playerId пуст")
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
    
    func sendNotification(date: String, address: String, playerId: String, formattedTime: String) {
        log("Отправка уведомления: У Вас запись на \(address) в \(formattedTime) [Дата: \(date)] для playerId: \(playerId)")
    }
    
    // MARK: - Помощники для работы с датами
    
    // Парсит дату из строки вида "yyyy-MM-dd HH:mm:ss"
    func recordDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
    
    // Форматирует дату для отображения, например: "14 февраля 15:30"
    func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // Получает 10 ближайших записей
    func upcomingTenRecords() -> [Record] {
        var upcoming: [Record] = []
        let now = Date()
        for (_, records) in recordsByCompany {
            for record in records {
                if let recordDate = recordDate(from: record.date), recordDate > now {
                    upcoming.append(record)
                }
            }
        }
        upcoming.sort {
            guard let d1 = recordDate(from: $0.date),
                  let d2 = recordDate(from: $1.date) else { return false }
            return d1 < d2
        }
        return Array(upcoming.prefix(10))
    }
    
    // Находит ближайшую запись
    func closestUpcomingRecord(records: [Record]) -> Record? {
        let now = Date()
        let futureRecords = records.filter {
            if let d = recordDate(from: $0.date) {
                return d > now
            }
            return false
        }
        let closest = futureRecords.min {
            guard let d1 = recordDate(from: $0.date),
                  let d2 = recordDate(from: $1.date) else { return false }
            return d1 < d2
        }
        if let closest = closest {
        } else {
        }
        return closest
    }
    
    // Форматирует запись для отображения (адрес и дата)
    func displayRecord(record: Record) -> (address: String, dateString: String) {
        let address = companyIdToAddress[String(record.company_id)] ?? ""
        guard let date = recordDate(from: record.date) else {
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
    @StateObject var viewModel = RecordViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                // Верхняя строка: два блока для "Коммунаров 26" и "Свердлова 126"
                HStack(spacing: 8) { // расстояние между блоками — 8
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
                        .frame(maxWidth: .infinity) // растягиваем каждый блок на доступную ширину
                    }
                }
                .frame(maxWidth: .infinity) // растягиваем HStack по всей доступной ширине
                .padding(.horizontal, 8) // отступы от краёв экрана

                
                // Горизонтальная лента с 10 ближайшими записями
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.upcomingTenRecords()) { record in
                            if let date = viewModel.recordDate(from: record.date) {
                                let address = viewModel.companyIdToAddress[String(record.company_id)] ?? ""
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
}

// MARK: - Запись с автоматическим подставлением специалиста

struct RecordRow: View {
    let address: String
    let date: String
    let customColor: String?
    let visit_attendance: Int?
    let attendance: Int?
    
    @State private var specialistName: String = ""
    @State private var checkmarkUrl: String? = nil
    
    // Проверка на подтверждённость записи (visit_attendance или attendance равны 2)
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
                .minimumScaleFactor(0.8) // или другое значение, например 0.7
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
                            // Убираем .background, .cornerRadius и лишние .padding,
                            // чтобы галочка выглядела как в модальном окне:
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
    
    /// Загружает URL иконки галочки из Firebase
    func loadCheckmarkUrl() {
        let ref = Database.database().reference(withPath: "specialists/checkmarkUrl")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let url = snapshot.value as? String {
                self.checkmarkUrl = url
            }
        }
    }
    
    /// Загружает имя специалиста из Firebase, подбирая по значению customColor
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

// MARK: - Нет записей (серый блок)

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
                .lineLimit(1)             // Только одна строка
                .minimumScaleFactor(0.8)  // Уменьшаем текст, если не помещается
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.9))
        .cornerRadius(12)
    }
}

// MARK: - Горизонтальная лента с 10 ближайшими записями

struct UpcomingRecordBlock: View {
    let date: Date
    let address: String
    
    var body: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1 // В Swift: воскресенье = 1
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

// MARK: - Модальное окно для детального просмотра записи



// MARK: - Окно для отладки (при необходимости)

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
