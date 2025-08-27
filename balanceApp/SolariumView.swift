import SwiftUI
import Firebase
import FirebaseDatabase
import Foundation
import AppMetricaCore

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
struct TimeSlot: Identifiable {
    let id = UUID()
    let displayTime: String
    let dateTimeString: String
}

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
    case cab    // Кабинеты 1-4 (Свердлова 126)
    case cab5   // Кабинеты 5-8 (Коммунаров 26)
}

// MARK: - Основная вью-модель
class SolariumViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var selectedType: SelectedType = .none
    @Published var isRefreshing: Bool = false
    
    @Published var availableTimes: [TimeSlot] = []
    
    @Published var availableTimesCab1: [TimeSlot] = []
    @Published var availableTimesCab2: [TimeSlot] = []
    @Published var availableTimesCab3: [TimeSlot] = []
    @Published var availableTimesCab4: [TimeSlot] = []
    @Published var availableTimesCab5: [TimeSlot] = []
    @Published var availableTimesCab6: [TimeSlot] = []
    @Published var availableTimesCab7: [TimeSlot] = []
    @Published var availableTimesCab8: [TimeSlot] = []
    
    @Published var cabinetsInfo: [String: CabinetData] = [:]
    
    init() {
        fetchCabinetsFromFirebase()
    }
    
    // MARK: - Firebase: загрузка данных о кабинетах
    private func fetchCabinetsFromFirebase() {
        let ref = Database.database().reference().child("cabinets")
        ref.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("Firebase: Нет данных для 'cabinets'")
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
                print("Firebase: Получены данные кабинетов - \(self.cabinetsInfo)")
            }
        }
    }
    
    // MARK: - Загрузка расписания для солярия (гориз./верт.)
    func loadSchedule(date: Date, staffId: String) async {
        await MainActor.run { self.isRefreshing = true }
        let dateString = formatDateForAPI(date: date)
        let urlString = "\(SCHEDULE_API_URL)/672239/\(staffId)/\(dateString)"
        print("Запрос расписания солярия по URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("Ошибка: некорректный URL")
            await MainActor.run { self.isRefreshing = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AUTH_TOKEN, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Ошибка: не удалось получить httpResponse")
                await MainActor.run { self.isRefreshing = false }
                return
            }
            print("Ответ сервера: \(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else {
                print("Ошибка запроса расписания, код статуса: \(httpResponse.statusCode)")
                await MainActor.run { self.isRefreshing = false }
                return
            }
            
            if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let success = result["success"] as? Bool, success == true,
               let dataArr = result["data"] as? [[String: Any]] {
                print("Получено расписание солярия, количество записей: \(dataArr.count)")
                
                let slots = dataArr.compactMap { dict -> TimeSlot? in
                    guard let datetimeStr = dict["datetime"] as? String,
                          let date = iso8601StringToDate(datetimeStr) else { return nil }
                    let minutes = Calendar.current.component(.minute, from: date)
                    let hour = Calendar.current.component(.hour, from: date)
                    if minutes % 15 == 0 && !(hour == 21 && minutes == 0) {
                        return TimeSlot(displayTime: formatDateToHHmm(date: date), dateTimeString: datetimeStr)
                    }
                    return nil
                }
                print("Форматирование солярия: найдено слотов: \(slots.count)")
                if slots.isEmpty {
                    print("Предупреждение: свободное время для солярия не найдено.")
                } else {
                    print("Свободные слоты солярия: \(slots.map { $0.displayTime })")
                }
                await MainActor.run {
                    self.availableTimes = slots
                }
            } else {
                print("Ошибка: success = false или отсутствует data в ответе для солярия.")
            }
        } catch {
            print("Ошибка загрузки расписания солярия: \(error)")
        }
        
        await MainActor.run { self.isRefreshing = false }
    }
    
    // MARK: - Загрузка расписания для кабинетов
    func loadCabSchedule(date: Date) async {
        await MainActor.run { self.isRefreshing = true }
        let dateString = formatDateForAPI(date: date)
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
            print("Запрос расписания кабинета по URL: \(req.url)")
            guard let url = URL(string: req.url) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(AUTH_TOKEN, forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Ошибка: не получен httpResponse для \(req.url)")
                    continue
                }
                print("Ответ для кабинета \(req.url) — код: \(httpResponse.statusCode)")
                guard httpResponse.statusCode == 200 else {
                    print("Ошибка запроса расписания для кабинета \(req.url), код статуса: \(httpResponse.statusCode)")
                    continue
                }
                
                if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let success = result["success"] as? Bool, success == true,
                   let dataArr = result["data"] as? [[String: Any]] {
                    print("Получено расписание для кабинета \(req.url), записей: \(dataArr.count)")
                    let formatted = formatDataForCabinet(dataArr: dataArr)
                    await MainActor.run {
                        req.completion(formatted)
                        if formatted.isEmpty {
                            print("Предупреждение: свободное время для кабинета (\(req.url)) не найдено.")
                        } else {
                            print("Свободные слоты кабинета (\(req.url)): \(formatted.map { $0.displayTime })")
                        }
                    }
                } else {
                    print("Ошибка: success = false или отсутствует data в ответе для кабинета (\(req.url))")
                }
            } catch {
                print("Ошибка загрузки расписания кабинета (\(req.url)): \(error)")
            }
        }
        
        await MainActor.run { self.isRefreshing = false }
    }
    
    // MARK: - Форматирование данных для солярия
    private func formatDataForSolarium(dataArr: [[String: Any]]) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        for dict in dataArr {
            if let datetimeStr = dict["datetime"] as? String,
               let date = iso8601StringToDate(datetimeStr) {
                let minutes = Calendar.current.component(.minute, from: date)
                let hour = Calendar.current.component(.hour, from: date)
                if minutes % 15 == 0 && !(hour == 21 && minutes == 0) {
                    let formattedTime = formatDateToHHmm(date: date)
                    slots.append(TimeSlot(displayTime: formattedTime, dateTimeString: datetimeStr))
                }
            }
        }
        print("Форматирование солярия: найдено слотов: \(slots.count)")
        return slots
    }
    
    // MARK: - Форматирование данных для кабинета
    private func formatDataForCabinet(dataArr: [[String: Any]]) -> [TimeSlot] {
        let excludedTimes = ["08:00", "08:30", "09:00", "09:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00"]
        var minutesFromStart: [(totalMinutes: Int, datetimeStr: String, date: Date)] = []
        
        for dict in dataArr {
            if let datetimeStr = dict["datetime"] as? String,
               let date = iso8601StringToDate(datetimeStr) {
                let totalMins = Calendar.current.component(.hour, from: date) * 60 +
                    Calendar.current.component(.minute, from: date)
                minutesFromStart.append((totalMins, datetimeStr, date))
            }
        }
        minutesFromStart.sort { $0.totalMinutes < $1.totalMinutes }
        let requiredInterval = 90
        let minInterval = 5
        let displayInterval = 30
        
        let intervalsRequired = requiredInterval / minInterval  // 18
        var availableWindows: [TimeSlot] = []
        
        for i in 0..<minutesFromStart.count {
            let windowStart = minutesFromStart[i].totalMinutes
            var intervalsFound = 1
            for j in (i+1)..<i+intervalsRequired {
                if j < minutesFromStart.count {
                    let diff = minutesFromStart[j].totalMinutes - windowStart
                    if diff == intervalsFound * minInterval {
                        intervalsFound += 1
                    } else {
                        break
                    }
                }
            }
            if intervalsFound == intervalsRequired {
                if windowStart % displayInterval == 0 {
                    let date = minutesFromStart[i].date
                    let displayTime = formatDateToHHmm(date: date)
                    if !excludedTimes.contains(displayTime) {
                        let slot = TimeSlot(displayTime: displayTime, dateTimeString: minutesFromStart[i].datetimeStr)
                        availableWindows.append(slot)
                    }
                }
            }
        }
        print("Форматирование кабинета: найдено окон: \(availableWindows.count)")
        return availableWindows
    }
    
    // MARK: - Бронирование
    @MainActor
    func bookService(selectedTime: TimeSlot, staffId: String, serviceType: SelectedType) async throws {
        guard let phone = UserDefaults.standard.string(forKey: "userPhone") else {
            throw BookingError.phoneNotFound
        }
        var serviceId = ""
        var bookRecordApiUrl = ""
        
        switch serviceType {
        case .horizontal:
            serviceId = "12807679" // Service ID for horizontal solarium
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .vertical:
            serviceId = "12807679" // Service ID for vertical solarium
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .cab:
            serviceId = "12831233" // Service ID for cabinets 1-4
            bookRecordApiUrl = BOOK_RECORD_API_URL_CAB
        case .cab5:
            serviceId = "12838467" // Service ID for cabinets 5-8
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
        
        print("Бронирование: отправка данных \(payload)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BookingError.noResponse
        }
        
        print("Бронирование: код ответа \(httpResponse.statusCode)")
        guard [200, 201, 400].contains(httpResponse.statusCode) else {
            throw BookingError.serverError
        }
        
        if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let success = result["success"] as? Bool, success == true {
                print("Бронирование прошло успешно")
                return
            } else {
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
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatDateToHHmm(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "d MMMM yyyy" // например, "24 февраля 2025"
        return formatter.string(from: date)
    }
    
    private func iso8601StringToDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: string)
    }
}

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
    @Environment(\.colorScheme) var colorScheme
    
    // Для показа диалога подтверждения бронирования с вариантами "Да" / "Нет"
    @State private var showConfirmationDialog = false
    @State private var pendingTimeSlot: TimeSlot?
    @State private var pendingStaffId: String = ""
    
    // Для показа информационного алерта об ошибке или успехе
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Group {
            if viewModel.selectedType == .none {
                startScreen
            } else {
                bookingScreen
            }
        }
        .navigationBarHidden(true)
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .confirmationDialog("Подтверждение записи", isPresented: $showConfirmationDialog, titleVisibility: .visible) {
            Button("Да") {
                handleBookingConfirmation()
            }
            Button("Нет", role: .cancel) { }
        } message: {
            // Здесь добавляем сообщение с датой и временем записи
            if let slot = pendingTimeSlot, let bookingDate = iso8601StringToDate(slot.dateTimeString) {
                Text("Запись на \(formattedDate(bookingDate)) в \(slot.displayTime)")
            } else {
                Text("")
            }
        }
        .task { }
    }
    
    // MARK: - Стартовый экран
    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                        Button(action: {
                            AppMetrica.reportEvent(name: "Пользователь выбрал горизонтальный солярий")
                            viewModel.selectedType = .horizontal
                        }) {
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Text("Горизонтальный солярий")
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .padding()
                                    Spacer()
                                    AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/solarium/gorizontal-solary.png")) { phase in
                                        if let image = phase.image {
                                            image.resizable()
                                                .scaledToFill()
                                                .frame(width: 130, height: geometry.size.height)
                                                .clipped()
                                        } else {
                                            ProgressView()
                                                .frame(width: 130, height: geometry.size.height)
                                        }
                                    }
                                }
                            }
                            .frame(height: 100)
                            .background(colorScheme == .dark ? Color.black : Color.blue.opacity(0.2))
                            .cornerRadius(20)
                        }
                
                        Button(action: {
                            AppMetrica.reportEvent(name: "Пользователь выбрал вертикальный солярий")
                            viewModel.selectedType = .vertical
                        }) {
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Text("Вертикальный солярий")
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .padding()
                                    Spacer()
                                    AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/solarium/vertical-solariy.png")) { phase in
                                        if let image = phase.image {
                                            image.resizable()
                                                .scaledToFill()
                                                .frame(width: 90, height: geometry.size.height)
                                                .clipped()
                                        } else {
                                            ProgressView()
                                                .frame(width: 90, height: geometry.size.height)
                                        }
                                    }
                                }
                            }
                            .frame(height: 100)
                            .background(colorScheme == .dark ? Color.black : Color.blue.opacity(0.2))
                            .cornerRadius(20)
                        }
                
                Button(action: {
                    AppMetrica.reportEvent(name: "Пользователь выбрал массаж на Свердлова 126")
                    viewModel.selectedType = .cab
                }) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Text("Массаж на Свердлова 126")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .padding()
                            Spacer()
                            AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/market/Foto_massage126_1.png")) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: geometry.size.height)
                                        .clipped()
                                } else {
                                    ProgressView()
                                        .frame(width: 120, height: geometry.size.height)
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    .background(colorScheme == .dark ? Color.black : Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
                
                Button(action: {
                    AppMetrica.reportEvent(name: "Пользователь выбрал массаж на Коммунаров 26")
                    viewModel.selectedType = .cab5
                }) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Text("Массаж на Коммунаров 26")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .padding()
                            Spacer()
                            AsyncImage(url: URL(string: "https://24balance.hb.ru-msk.vkcs.cloud/market/Foto_massage26_2.png")) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: geometry.size.height)
                                        .clipped()
                                } else {
                                    ProgressView()
                                        .frame(width: 120, height: geometry.size.height)
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    .background(colorScheme == .dark ? Color.black : Color.blue.opacity(0.2))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Экран с расписанием
    private var bookingScreen: some View {
        ScrollView {
            VStack {
                HStack {
                    Button(action: { viewModel.selectedType = .none }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                Text(titleForSelectedType)
                    .font(.title)
                    .bold()
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color.blue.opacity(0.2))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                datePickerView
                
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
                
                if viewModel.selectedType == .cab {
                    cabinetSection(cabKey: "CAB_1", slots: viewModel.availableTimesCab1, staffId: CAB_1)
                    cabinetSection(cabKey: "CAB_2", slots: viewModel.availableTimesCab2, staffId: CAB_2)
                    cabinetSection(cabKey: "CAB_3", slots: viewModel.availableTimesCab3, staffId: CAB_3)
                    cabinetSection(cabKey: "CAB_4", slots: viewModel.availableTimesCab4, staffId: CAB_4)
                } else if viewModel.selectedType == .cab5 {
                    cabinetSection(cabKey: "CAB_5", slots: viewModel.availableTimesCab5, staffId: CAB_5)
                    cabinetSection(cabKey: "CAB_6", slots: viewModel.availableTimesCab6, staffId: CAB_6)
                    cabinetSection(cabKey: "CAB_7", slots: viewModel.availableTimesCab7, staffId: CAB_7)
                    cabinetSection(cabKey: "CAB_8", slots: viewModel.availableTimesCab8, staffId: CAB_8)
                }
            }
        }
        .refreshable { await reloadData() }
        .onAppear { Task { await reloadData() } }
    }
    
    // MARK: - DatePicker
    private var datePickerView: some View {
        DatePicker(
            "Выберите дату",
            selection: $viewModel.selectedDate,
            displayedComponents: [.date]
        )
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .datePickerStyle(.compact)
        .labelsHidden()
        .padding()
        .onChange(of: viewModel.selectedDate) {
            Task { await reloadData() }
        }
    }
    
    // MARK: - Перезагрузка данных
    private func reloadData() async {
        if viewModel.selectedType == .cab || viewModel.selectedType == .cab5 {
            await viewModel.loadCabSchedule(date: viewModel.selectedDate)
        } else if viewModel.selectedType == .horizontal {
            await viewModel.loadSchedule(date: viewModel.selectedDate, staffId: HORIZONTAL_SOLARIUM)
        } else if viewModel.selectedType == .vertical {
            await viewModel.loadSchedule(date: viewModel.selectedDate, staffId: VERTICAL_SOLARIUM)
        }
    }
    
    // MARK: - Кабинет секция
    @ViewBuilder
    private func cabinetSection(cabKey: String, slots: [TimeSlot], staffId: String) -> some View {
        VStack {
            if let cabinet = viewModel.cabinetsInfo[cabKey] {
                Text(cabinet.name)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                AsyncImage(url: URL(string: cabinet.image)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.15)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120, alignment: .top)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.gray.opacity(0.4), lineWidth: 2)
                            )
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 120, height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 120, height: 120)
                if slots.isEmpty {
                    Text(cabinet.noAvailabilityMessage)
                        .foregroundColor(.gray)
                } else {
                    timeGrid(times: slots, staffId: staffId)
                }
            } else {
                Text("Загрузка...")
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Сетка времени
    private func timeGrid(times: [TimeSlot], staffId: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 10), count: 5), spacing: 10) {
            ForEach(times) { slot in
                Button {
                    let type = viewModel.selectedType
                    let eventName = (type == .cab || type == .cab5)
                        ? "Пользователь выбрал время записи на массаж"
                        : "Пользователь выбрал время записи на солярий"
                    AppMetrica.reportEvent(
                        name: eventName,
                        parameters: ["время": slot.displayTime]
                    )
                    pendingTimeSlot = slot
                    pendingStaffId = staffId
                    showConfirmationDialog = true
                    print("Выбран слот \(slot.displayTime) для записи")
                } label: {
                    Text(slot.displayTime)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Заголовок
    private var titleForSelectedType: String {
        switch viewModel.selectedType {
        case .horizontal:
            return "Горизонтальный солярий"
        case .vertical:
            return "Вертикальный солярий"
        case .cab:
            return "Массаж на Свердлова 126"
        case .cab5:
            return "Массаж на Коммунаров 26"
        default:
            return ""
        }
    }
    
    // MARK: - Обработка подтверждения бронирования
    private func handleBookingConfirmation() {
        guard let slot = pendingTimeSlot else { return }
        AppMetrica.reportEvent(
            name: "Пользователь подтвердил запись",
            parameters: ["время": slot.displayTime]
        )
        print("Подтверждение записи на \(slot.displayTime)")
        Task {
            do {
                try await viewModel.bookService(selectedTime: slot,
                                                staffId: pendingStaffId,
                                                serviceType: viewModel.selectedType)
                alertMessage = "Вы успешно записались!"
                print("Запись успешна. Обновляем данные...")
                if let bookingDate = iso8601StringToDate(slot.dateTimeString) {
                    AppMetrica.reportEvent(
                        name: "Бронирование прошло успешно",
                        parameters: [
                            "дата": formattedDate(bookingDate),
                            "время": slot.displayTime
                        ]
                    )
                }
                await reloadData()
            } catch {
                let errorText = (error as? BookingError)?.errorDescription ?? error.localizedDescription
                alertMessage = "Ошибка записи: \(errorText)"
                print("Ошибка бронирования: \(errorText)")
            }
            showAlert = true
        }
    }
    
    // MARK: - Локальные функции для форматирования даты (для использования в диалоге)
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "d MMMM yyyy" // например, "24 февраля 2025"
        return formatter.string(from: date)
    }
    
    private func iso8601StringToDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: string)
    }
    
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
    
    struct SolariumView_Previews: PreviewProvider {
        static var previews: some View {
            SolariumView()
                .preferredColorScheme(.light)
            SolariumView()
                .preferredColorScheme(.dark)
        }
    }
}
