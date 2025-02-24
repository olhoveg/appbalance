import SwiftUI
import Firebase
import FirebaseDatabase

// MARK: - Константы и идентификаторы
fileprivate let SCHEDULE_API_URL = "https://api.yclients.com/api/v1/book_times"
fileprivate let BOOK_RECORD_API_URL_CAB = "https://api.yclients.com/api/v1/book_record/672239"
fileprivate let BOOK_RECORD_API_URL_OTHER_CAB = "https://api.yclients.com/api/v1/book_record/433675"

fileprivate let HORIZONTAL_SOLARIUM = "1921420"
fileprivate let VERTICAL_SOLARIUM = "2072973"

fileprivate let CAB_1 = "1920691"
fileprivate let CAB_2 = "1921385"
fileprivate let CAB_3 = "1921384"
fileprivate let CAB_4 = "1921383"

fileprivate let CAB_5 = "1320742"
fileprivate let CAB_6 = "1262910"
fileprivate let CAB_7 = "1312437"
fileprivate let CAB_8 = "1269725"

fileprivate let AUTH_TOKEN = "Bearer 88fnh8jbmt44er5y28nj"

// MARK: - Модели
/// Модель для хранения данных о конкретном "окне времени"
struct TimeSlot: Identifiable {
    let id = UUID()
    let displayTime: String
    let dateTimeString: String
}

/// Модель для хранения данных о кабинете, полученных из Firebase
struct CabinetData {
    let name: String
    let image: String
    let noAvailabilityMessage: String
    
    init(name: String, image: String, noAvailabilityMessage: String) {
        self.name = name
        self.image = image
        self.noAvailabilityMessage = noAvailabilityMessage
    }
    
    init?(dict: [String: Any]) {
        guard
            let name = dict["name"] as? String,
            let image = dict["image"] as? String,
            let noAvailabilityMessage = dict["noAvailabilityMessage"] as? String
        else {
            return nil
        }
        self.name = name
        self.image = image
        self.noAvailabilityMessage = noAvailabilityMessage
    }
}

// MARK: - Enum для выбора типа услуги
enum SelectedType {
    case none
    case horizontal
    case vertical
    case cab    // подразумевает каб 1-4 (Свердлова 126)
    case cab5   // подразумевает каб 5-8 (Коммунаров 26)
}

// MARK: - Основная вью-модель
class SolariumViewModel: ObservableObject {
    // Основные публикуемые свойства
    @Published var selectedDate: Date = Date()
    @Published var selectedType: SelectedType = .none
    @Published var isRefreshing: Bool = false
    
    // Доступные интервалы времени для солярия (гориз. и верт.)
    @Published var availableTimes: [TimeSlot] = []
    
    // Доступные интервалы для каждого кабинета
    @Published var availableTimesCab1: [TimeSlot] = []
    @Published var availableTimesCab2: [TimeSlot] = []
    @Published var availableTimesCab3: [TimeSlot] = []
    @Published var availableTimesCab4: [TimeSlot] = []
    @Published var availableTimesCab5: [TimeSlot] = []
    @Published var availableTimesCab6: [TimeSlot] = []
    @Published var availableTimesCab7: [TimeSlot] = []
    @Published var availableTimesCab8: [TimeSlot] = []
    
    // Хранение данных о кабинетах из Firebase
    // Ключи "CAB_1", "CAB_2" и т.д.
    @Published var cabinetsInfo: [String: CabinetData] = [:]
    
    // Инициализатор, можно вызывать чтение Firebase здесь
    init() {
        fetchCabinetsFromFirebase()
    }
    
    // MARK: - Firebase: загрузка данных о кабинетах
    private func fetchCabinetsFromFirebase() {
        let ref = Database.database().reference().child("cabinets")
        ref.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("No data available for 'cabinets'")
                return
            }
            
            var newInfo: [String: CabinetData] = [:]
            for (key, dict) in value {
                if let dict = dict as? [String: Any], let cabinet = CabinetData(dict: dict) {
                    newInfo[key] = cabinet
                }
            }
            DispatchQueue.main.async {
                self.cabinetsInfo = newInfo
            }
        }
    }
    
    // MARK: - Загрузка расписания для Солярия (гориз./верт.)
    func loadSchedule(date: Date, staffId: String) async {
        isRefreshing = true
        let dateString = formatDateForAPI(date: date)
        
        // Пример URL: https://api.yclients.com/api/v1/book_times/672239/1921420/2025-02-24
        guard let url = URL(string: "\(SCHEDULE_API_URL)/672239/\(staffId)/\(dateString)") else {
            print("Invalid URL")
            isRefreshing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AUTH_TOKEN, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Schedule request failed")
                isRefreshing = false
                return
            }
            
            if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let success = result["success"] as? Bool, success == true,
               let dataArr = result["data"] as? [[String: Any]] {
                
                // Обрабатываем dataArr
                let slots = formatDataForSolarium(dataArr: dataArr)
                DispatchQueue.main.async {
                    self.availableTimes = slots
                }
            }
        } catch {
            print("Error fetching schedule: \(error)")
        }
        
        isRefreshing = false
    }
    
    // MARK: - Загрузка расписания для кабинетов
    func loadCabSchedule(date: Date) async {
        isRefreshing = true
        let dateString = formatDateForAPI(date: date)
        
        // Массив запросов
        let requests: [(url: String, completion: @MainActor ([TimeSlot]) -> Void)] = [
            ("\(SCHEDULE_API_URL)/672239/\(CAB_1)/\(dateString)", { [weak self] data in self?.availableTimesCab1 = data }),
            ("\(SCHEDULE_API_URL)/672239/\(CAB_2)/\(dateString)", { [weak self] data in self?.availableTimesCab2 = data }),
            ("\(SCHEDULE_API_URL)/672239/\(CAB_3)/\(dateString)", { [weak self] data in self?.availableTimesCab3 = data }),
            ("\(SCHEDULE_API_URL)/672239/\(CAB_4)/\(dateString)", { [weak self] data in self?.availableTimesCab4 = data }),
            ("\(SCHEDULE_API_URL)/433675/\(CAB_5)/\(dateString)", { [weak self] data in self?.availableTimesCab5 = data }),
            ("\(SCHEDULE_API_URL)/433675/\(CAB_6)/\(dateString)", { [weak self] data in self?.availableTimesCab6 = data }),
            ("\(SCHEDULE_API_URL)/433675/\(CAB_7)/\(dateString)", { [weak self] data in self?.availableTimesCab7 = data }),
            ("\(SCHEDULE_API_URL)/433675/\(CAB_8)/\(dateString)", { [weak self] data in self?.availableTimesCab8 = data })
        ]
        
        for req in requests {
            guard let url = URL(string: req.url) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(AUTH_TOKEN, forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("Cab schedule request failed for \(req.url)")
                    continue
                }
                
                if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let success = result["success"] as? Bool, success == true,
                   let dataArr = result["data"] as? [[String: Any]] {
                    
                    let formatted = formatDataForCabinet(dataArr: dataArr)
                    // Обновляем соответствующий стейт
                    await MainActor.run {
                        req.completion(formatted)
                    }
                }
            } catch {
                print("Error fetching cab schedule: \(error)")
            }
        }
        
        isRefreshing = false
    }
    
    // MARK: - Форматирование данных для Солярия (каждые 15 минут, исключая 21:00)
    private func formatDataForSolarium(dataArr: [[String: Any]]) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        
        for dict in dataArr {
            if let datetimeStr = dict["datetime"] as? String,
               let date = iso8601StringToDate(datetimeStr) {
                
                let minutes = Calendar.current.component(.minute, from: date)
                let hour = Calendar.current.component(.hour, from: date)
                
                // Шаг 15 минут, исключая "21:00"
                if minutes % 15 == 0 && !(hour == 21 && minutes == 0) {
                    let formattedTime = formatDateToHHmm(date: date)
                    slots.append(TimeSlot(displayTime: formattedTime, dateTimeString: datetimeStr))
                }
            }
        }
        
        return slots
    }
    
    // MARK: - Форматирование данных для Кабинета (90 минут шагом по 5, отображаем каждые 30 минут)
    private func formatDataForCabinet(dataArr: [[String: Any]]) -> [TimeSlot] {
        // Интервал, который нужно занять (90 минут) разбитый на 5-минутные слоты => нужно 18 подряд идущих 5-минутных слотов
        // Для отображения берём шаг 30 минут => каждые 6 пятиминуток
        // Имеется список "запрещённых" времён
        let excludedTimes = ["08:00", "08:30", "09:00", "09:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00"]
        
        // Конвертируем все время из ответа в минуты с начала дня
        var minutesFromStart: [(totalMinutes: Int, datetimeStr: String, date: Date)] = []
        
        for dict in dataArr {
            if let datetimeStr = dict["datetime"] as? String,
               let date = iso8601StringToDate(datetimeStr) {
                
                let totalMins = Calendar.current.component(.hour, from: date) * 60 +
                                Calendar.current.component(.minute, from: date)
                
                minutesFromStart.append((totalMins, datetimeStr, date))
            }
        }
        
        minutesFromStart.sort { $0.totalMinutes < $1.totalMinutes } // на всякий случай
        
        let requiredInterval = 90    // минут
        let minInterval = 5         // минут
        let displayInterval = 30    // минут
        
        let intervalsRequired = requiredInterval / minInterval   // 90 / 5 = 18
        let displayIntervals = displayInterval / minInterval     // 30 / 5 = 6
        
        var availableWindows: [TimeSlot] = []
        
        // Поиск подходящих "окон" длиной 90 минут (из данных, которые идут подряд каждые 5 минут)
        for i in 0..<minutesFromStart.count {
            let windowStart = minutesFromStart[i].totalMinutes
            var intervalsFound = 1
            
            for j in (i+1)..<i+intervalsRequired {
                if j < minutesFromStart.count {
                    let diff = minutesFromStart[j].totalMinutes - windowStart
                    // Проверяем, что каждые 5 минут подряд
                    if diff == intervalsFound * minInterval {
                        intervalsFound += 1
                    } else {
                        break
                    }
                }
            }
            
            // Если нашли всю цепочку
            if intervalsFound == intervalsRequired {
                // Доп.условие: окно начинается на 30-минутной отметке (например, 540 — это 09:00, 570 — 09:30)
                if windowStart % displayInterval == 0 {
                    let date = minutesFromStart[i].date
                    let displayTime = formatDateToHHmm(date: date)
                    // Исключаем нежелательные интервалы
                    if !excludedTimes.contains(displayTime) {
                        let slot = TimeSlot(displayTime: displayTime,
                                            dateTimeString: minutesFromStart[i].datetimeStr)
                        availableWindows.append(slot)
                    }
                }
            }
        }
        
        return availableWindows
    }
    
    // MARK: - Бронирование
    /// Функция для отправки POST-запроса на бронирование
    @MainActor
    func bookService(selectedTime: TimeSlot, staffId: String, serviceType: SelectedType) async throws {
        // Получаем телефон из UserDefaults (аналог AsyncStorage)
        guard let phone = UserDefaults.standard.string(forKey: "phone") else {
            throw BookingError.phoneNotFound
        }
        
        var serviceId = ""
        var bookRecordApiUrl = ""
        
        switch serviceType {
        case .horizontal:
            // Горизонтальный солярий
            serviceId = "12807679"
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .vertical:
            // Вертикальный солярий
            serviceId = "12807679"
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .cab:
            // Кабинеты 1-4
            serviceId = "12831233"
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .cab5:
            // Кабинеты 5-8
            serviceId = "12838467"
            bookRecordApiUrl = BOOK_RECORD_API_URL_OTHER_CAB
        default:
            break
        }
        
        guard let url = URL(string: bookRecordApiUrl) else {
            throw BookingError.invalidURL
        }
        
        let payload: [String: Any] = [
            "phone": phone,
            "fullname": "1",
            "email": "",
            "appointments": [
                [
                    "datetime": selectedTime.dateTimeString,
                    "services": serviceId,
                    "id": "1",
                    "staff_id": staffId
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AUTH_TOKEN, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BookingError.noResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 400 else {
            throw BookingError.serverError
        }
        
        if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let success = result["success"] as? Bool, success == true {
                // Успешная запись
                return
            } else {
                // Ошибка записи
                if let meta = result["meta"] as? [String: Any],
                   let message = meta["message"] as? String {
                    throw BookingError.custom(message)
                } else {
                    throw BookingError.unknown
                }
            }
        } else {
            throw BookingError.unknown
        }
    }
    
    // MARK: - Хелперы
    private func formatDateForAPI(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatDateToHHmm(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func iso8601StringToDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: string)
    }
}

// MARK: - Перечисление возможных ошибок при бронировании
enum BookingError: Error, LocalizedError {
    case phoneNotFound
    case invalidURL
    case noResponse
    case serverError
    case unknown
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .phoneNotFound:
            return "Номер телефона не найден. Авторизуйтесь, чтобы продолжить."
        case .invalidURL:
            return "Некорректный URL."
        case .noResponse:
            return "Нет ответа от сервера."
        case .serverError:
            return "Ошибка сервера."
        case .unknown:
            return "Неизвестная ошибка."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Основной SwiftUI-экран
struct SolariumView: View {
    @StateObject private var viewModel = SolariumViewModel()
    
    // Для показа Alert (подтверждение бронирования и пр.)
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var pendingTimeSlot: TimeSlot?
    @State private var pendingStaffId: String = ""
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.selectedType == .none {
                    // Стартовый экран с кнопками
                    startScreen
                } else {
                    // Экран с выбором дат, отображением расписания и т.д.
                    bookingScreen
                }
            }
            .navigationBarHidden(true)
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
        }
        .task {
            // При старте можно загрузить что-то, если нужно
        }
    }
    
    // MARK: - Стартовый экран
    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Горизонтальный солярий
                Button(action: {
                    viewModel.selectedType = .horizontal
                }) {
                    HStack {
                        Text("Горизонтальный солярий")
                            .foregroundColor(.black)
                        Spacer()
                        // Пример использования AsyncImage для отображения картинки
                        AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/solarium/gorizontal-solary.png")) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
                
                // Вертикальный солярий
                Button(action: {
                    viewModel.selectedType = .vertical
                }) {
                    HStack {
                        Text("Вертикальный солярий")
                            .foregroundColor(.black)
                        Spacer()
                        AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/solarium/vertical-solariy.png")) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
                
                // Массаж на Свердлова 126
                Button(action: {
                    viewModel.selectedType = .cab
                }) {
                    HStack {
                        Text("Массаж на Свердлова 126")
                            .foregroundColor(.black)
                        Spacer()
                        AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/market/Foto_massage126_1.png")) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
                
                // Массаж на Коммунаров 26
                Button(action: {
                    viewModel.selectedType = .cab5
                }) {
                    HStack {
                        Text("Массаж на Коммунаров 26")
                            .foregroundColor(.black)
                        Spacer()
                        AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/market/Foto_massage26_2.png")) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Экран с расписанием (solarium / cabinets)
    private var bookingScreen: some View {
        ScrollView {
            VStack {
                // Кнопка "Назад"
                HStack {
                    Button(action: {
                        viewModel.selectedType = .none
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Заголовок
                Text(titleForSelectedType)
                    .font(.title)
                    .bold()
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.black)
                
                // Дата (DatePicker)
                datePickerView
                
                // Если это солярий (horizontal/vertical) — показываем доступные времена
                if viewModel.selectedType == .horizontal || viewModel.selectedType == .vertical {
                    if viewModel.availableTimes.isEmpty {
                        Text("Нет свободных слотов")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        timeGrid(times: viewModel.availableTimes,
                                 staffId: (viewModel.selectedType == .horizontal ? HORIZONTAL_SOLARIUM : VERTICAL_SOLARIUM))
                    }
                }
                
                // Если это "cab" (1-4) или "cab5" (5-8)
                if viewModel.selectedType == .cab {
                    // Свердлова 126: CAB_1, CAB_2, CAB_3, CAB_4
                    cabinetSection(cabKey: "CAB_1", slots: viewModel.availableTimesCab1, staffId: CAB_1)
                    cabinetSection(cabKey: "CAB_2", slots: viewModel.availableTimesCab2, staffId: CAB_2)
                    cabinetSection(cabKey: "CAB_3", slots: viewModel.availableTimesCab3, staffId: CAB_3)
                    cabinetSection(cabKey: "CAB_4", slots: viewModel.availableTimesCab4, staffId: CAB_4)
                } else if viewModel.selectedType == .cab5 {
                    // Коммунаров 26: CAB_5, CAB_6, CAB_7, CAB_8
                    cabinetSection(cabKey: "CAB_5", slots: viewModel.availableTimesCab5, staffId: CAB_5)
                    cabinetSection(cabKey: "CAB_6", slots: viewModel.availableTimesCab6, staffId: CAB_6)
                    cabinetSection(cabKey: "CAB_7", slots: viewModel.availableTimesCab7, staffId: CAB_7)
                    cabinetSection(cabKey: "CAB_8", slots: viewModel.availableTimesCab8, staffId: CAB_8)
                }
            }
        }
        .refreshable {
            // Обновление при "pull to refresh"
            await reloadData()
        }
        .onAppear {
            // При первом появлении экрана загружаем расписание
            Task {
                await reloadData()
            }
        }
    }
    
    // MARK: - View: DatePicker
    private var datePickerView: some View {
        DatePicker(
            "Выберите дату",
            selection: $viewModel.selectedDate,
            displayedComponents: [.date]
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .padding()
        .onChange(of: viewModel.selectedDate) { newDate in
            Task {
                await reloadData()
            }
        }
    }
    
    // MARK: - Перегрузка данных при выборе даты/типа
    private func reloadData() async {
        if viewModel.selectedType == .cab || viewModel.selectedType == .cab5 {
            // Загрузка расписаний для всех кабинетов
            await viewModel.loadCabSchedule(date: viewModel.selectedDate)
        } else if viewModel.selectedType == .horizontal {
            await viewModel.loadSchedule(date: viewModel.selectedDate, staffId: HORIZONTAL_SOLARIUM)
        } else if viewModel.selectedType == .vertical {
            await viewModel.loadSchedule(date: viewModel.selectedDate, staffId: VERTICAL_SOLARIUM)
        }
    }
    
    // MARK: - Секция для конкретного кабинета (имя, картинка, расписание)
    @ViewBuilder
    private func cabinetSection(cabKey: String, slots: [TimeSlot], staffId: String) -> some View {
        VStack {
            if let cabinet = viewModel.cabinetsInfo[cabKey] {
                Text(cabinet.name)
                    .font(.headline)
                
                AsyncImage(url: URL(string: cabinet.image)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    } else {
                        ProgressView()
                            .frame(width: 120, height: 120)
                    }
                }
                
                if slots.isEmpty {
                    Text(cabinet.noAvailabilityMessage)
                        .foregroundColor(.gray)
                } else {
                    timeGrid(times: slots, staffId: staffId)
                }
            } else {
                // Нет данных из Firebase
                Text("Загрузка...")
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - "Сетка" времени
    private func timeGrid(times: [TimeSlot], staffId: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 10), count: 5), spacing: 10) {
            ForEach(times) { slot in
                Button(slot.displayTime) {
                    // При нажатии спрашиваем подтверждение бронирования
                    pendingTimeSlot = slot
                    pendingStaffId = staffId
                    showConfirmationAlert(slot: slot, staffId: staffId)
                }
                .frame(height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.black)
            }
        }
        .padding()
    }
    
    // MARK: - Заголовок в зависимости от выбранного типа
    private var titleForSelectedType: String {
        switch viewModel.selectedType {
        case .horizontal:
            return "Горизонтальный солярий"
        case .vertical:
            return "Вертикальный солярий"
        case .cab:
            return "Свердлова 126"
        case .cab5:
            return "Коммунаров 26"
        default:
            return ""
        }
    }
    
    // MARK: - Alert c подтверждением
    private func showConfirmationAlert(slot: TimeSlot, staffId: String) {
        let message = "Вы уверены, что хотите записаться на время \(slot.displayTime)?"
        alertMessage = message
        
        // Используем .confirmationDialog или .alert
        // Для демонстрации воспользуемся .alert:
        
        showAlert = true
    }
    
    // MARK: - Обработка нажатия "Да" в алерте (прямо внутри .alert(...) не всегда удобно, поэтому можно через дополнительное свойство)
    // В нашем случае для упрощения используем showAlert + alertMessage, но если нужно прям "Да/Нет", лучше .confirmationDialog
    private func handleBookingConfirmation() {
        guard let slot = pendingTimeSlot else { return }
        
        Task {
            do {
                try await viewModel.bookService(selectedTime: slot,
                                                staffId: pendingStaffId,
                                                serviceType: viewModel.selectedType)
                // Успешная запись
                alertMessage = "Вы успешно записались!"
                showAlert = true
                // Обновляем расписание
                await reloadData()
            } catch {
                let errorText = (error as? BookingError)?.errorDescription ?? error.localizedDescription
                alertMessage = "Ошибка записи: \(errorText)"
                showAlert = true
            }
        }
    }
}

// MARK: - Пример .confirmationDialog, если хочется "Да/Нет"
extension SolariumView {
    // Пример, как можно сделать диалог подтверждения
    private func bookingConfirmationDialog() -> some View {
        Group {
            if let slot = pendingTimeSlot {
                Text("Вы уверены, что хотите записаться на \(slot.displayTime)?")
            } else {
                Text("Выберите время")
            }
        }
    }
}

// MARK: - Пример, как можно использовать .alert с двумя кнопками
// Более гибкий способ с отдельными состояниями
extension SolariumView {
    @ViewBuilder
    private func bookingAlert() -> some View {
        // Пример, если нужен .alert c двумя кнопками:
        // .alert("Подтверждение записи", isPresented: $showAlert) {
        //   Button("Да") { handleBookingConfirmation() }
        //   Button("Нет", role: .cancel) {}
        // } message: {
        //   Text(alertMessage)
        // }
        EmptyView()
    }
}

// MARK: - Пример использования SwiftUI Preview
struct SolariumView_Previews: PreviewProvider {
    static var previews: some View {
        SolariumView()
    }
}
