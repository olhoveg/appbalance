//RecordModalView.swift


import SwiftUI
import FirebaseDatabase

// MARK: - Дополнительные модели (при необходимости)

struct Service: Identifiable, Codable {
    let id: Int
    let title: String
    let cost: Double
}

struct Staff: Codable {
    let name: String
    let avatar_big: String?
    let specialization: String
}

// Модель специалиста из Firebase
struct FirebaseSpecialist {
    let fullName: String
    let avatar: String?
    let specialistRole: String
}

// Модель для модального окна (аналог IRecord из React Native)
struct RecordModal: Identifiable, Codable {
    let company_id: Int
    let date: String
    let id: Int
    let last_change_date: String
    let custom_color: String?
    let attendance: Int?      // 2 – подтверждённая запись
    let visit_attendance: Int?
    // Дополнительные поля:
    let visit_id: Int?
    let length: Int          // длительность записи в секундах
    let services: [Service]?
    let staff: Staff?
    
    private enum CodingKeys: String, CodingKey {
        case company_id, date, id, last_change_date, custom_color, attendance, visit_attendance, visit_id, length, services, staff
    }
}

// MARK: - Модальное окно RecordModalView

struct RecordModalView: View {
    let record: RecordModal
    @ObservedObject var viewModel: RecordViewModel
    
    @State private var firebaseSpecialist: FirebaseSpecialist? = nil
    @State private var branchName: String? = nil
    @State private var branchAddress: String? = nil
    @State private var mapImage: String? = nil
    @State private var checkmarkUrl: String? = nil
    
    // Состояния для отображения предупреждений
    @State private var showConfirmationAlert = false
    @State private var showDeleteAlert = false
    
    @Environment(\.colorScheme) var colorScheme
    
    // Форматтеры для вывода даты и времени (уже настроены на русский)
    private var headerDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "d MMMM"  // например, "7 февраля"
        return formatter
    }
    
    private var headerTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "HH:mm"   // 24-часовой формат
        return formatter
    }
    
    // Функция для парсинга даты с логированием
    func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        
        // Попытка с форматом ISO8601
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            print("Parsed date using ISO8601 format: \(date)")
            return date
        }
        
        // Фолбэк: формат без символов "T" и "Z"
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            print("Parsed date using fallback format: \(date)")
            return date
        }
        
        print("Failed to parse date: \(dateString)")
        return nil
    }
    
    var body: some View {
        VStack {
            ScrollView {
                // Заголовок с датой и временем
                VStack(alignment: .leading, spacing: 8) {
                    if let startDate = parseDate(record.date) {
                        let duration = record.length
                        let endDate = calculateEndTime(start: startDate, duration: duration)
                        
                        // Форматирование для отображения
                        let dateString = headerDateFormatter.string(from: startDate)
                        let startTimeString = headerTimeFormatter.string(from: startDate)
                        let endTimeString = headerTimeFormatter.string(from: endDate)
                        
                        HStack(spacing: 8) {
                            Text("\(dateString), \(startTimeString) - \(endTimeString)")
                            // Используем динамический цвет для основного текста:
                                .font(.headline)
                                .foregroundColor(record.attendance == 2 ? .white : .primary)
                            
                            // Галочка, если запись подтверждена
                            if record.attendance == 2,
                               let checkmarkUrl = checkmarkUrl,
                               let url = URL(string: checkmarkUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 25, height: 25)
                            }
                        }
                    }
                }
                .padding()
                // Для фона можно использовать динамический цвет (например, systemGray6)
                .background(record.attendance == 2 ? Color.green : Color(UIColor.systemGray5))
                .cornerRadius(10)
                .padding(.bottom, 10)
                
                // Блок специалиста
                if let specialist = firebaseSpecialist {
                    HStack(spacing: 16) {
                        if let avatar = specialist.avatar,
                           let avatarUrl = URL(string: avatar) {
                            AsyncImage(url: avatarUrl) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(UIColor.systemGray4)
                            }
                            .frame(width: 70, height: 70)
                            .cornerRadius(15)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(specialist.fullName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text(specialist.specialistRole)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                        Spacer()
                    }
                    .padding()
                } else {
                    Text("Специалист не указан")
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Блок услуг
                if let services = record.services, !services.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Услуги")
                            .font(.headline)
                            .foregroundColor(.primary)
                        ForEach(services) { service in
                            HStack {
                                Text(service.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(service.cost, specifier: "%.0f") ₽")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                            if service.id != services.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.bottom, 10)
                    .onAppear {
                        print("Record \(record.id) has \(services.count) services")
                        for service in services {
                            print("Service id: \(service.id), title: \(service.title), cost: \(service.cost)")
                        }
                    }
                } else {
                    Text("Нет услуг для этой записи")
                        .foregroundColor(.secondary)
                        .onAppear {
                            print("Record \(record.id) has no services")
                        }
                }
                
                // Блок локации
                VStack(alignment: .center, spacing: 8) {
                    Text(branchName ?? (record.company_id == 433675 ? "BALANCE на Коммунаров 26" : "BALANCE на Свердлова 126"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let mapImage = mapImage,
                       let mapUrl = URL(string: mapImage) {
                        AsyncImage(url: mapUrl) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(UIColor.systemGray4)
                        }
                        .frame(height: 150)
                        .cornerRadius(10)
                    }
                    Text(branchAddress ?? (record.company_id == 433675 ? "улица Коммунаров, 26" : "улица Свердлова, 126"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .padding(.bottom, 10)
                
                // Кнопка подтверждения
                if record.attendance != 2 {
                    Button(action: {
                        showConfirmationAlert = true
                    }) {
                        Text("Подтвердить запись")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .alert("Подтверждение записи", isPresented: $showConfirmationAlert) {
                        Button("Отмена", role: .cancel) {}
                        Button("Подтвердить", role: .none) {
                            confirmRecord()
                        }
                    } message: {
                        Text("Вы уверены, что хотите подтвердить эту запись?")
                    }
                }
                
                // Кнопка удаления
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("Удалить запись")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .alert("Удаление записи", isPresented: $showDeleteAlert) {
                    Button("Отмена", role: .cancel) {}
                    Button("Удалить", role: .destructive) {
                        confirmDelete()
                    }
                } message: {
                    Text("Вы уверены, что хотите удалить эту запись? Это действие нельзя отменить.")
                }
                
                // Контактная информация (иконки звонка, сайта, WhatsApp)
                HStack(spacing: 20) {
                    Button {
                        openLink(url: "tel:+79615805108")
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        openLink(url: "https://24balance.ru")
                    } label: {
                        Image(systemName: "globe")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        openLink(url: "https://wa.me/message/AURK3MS65RQ5K1")
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    }
                }
                
                // Кнопка закрытия
                Button(action: {
                    viewModel.showModal = false
                }) {
                    Text("Закрыть")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.bottom, 60)
        }
        // Используем динамический цвет для подложки модального окна
        .background(Color(UIColor.systemGray6))
        .cornerRadius(20)
        .padding()
        .onAppear {
            // Вывод отладочной информации
            print("Record received: \(record)")
            print("Record length: \(record.length) секунд, что составляет \(record.length / 60) минут")
            
            if let startDate = parseDate(record.date) {
                let duration = record.length > 0 ? record.length : 600
                let endDate = calculateEndTime(start: startDate, duration: duration)
                print("Start date: \(startDate)")
                print("Computed duration: \(duration) секунд (\(duration / 60) минут)")
                print("Computed end date: \(endDate)")
                print("Start time (Moscow): \(headerTimeFormatter.string(from: startDate))")
                print("End time (Moscow): \(headerTimeFormatter.string(from: endDate))")
            } else {
                print("Unable to parse date from: \(record.date)")
            }
            loadFirebaseData()
        }
    }
    
    // MARK: - Firebase загрузка данных
    
    func loadFirebaseData() {
        loadSpecialistData()
        loadCheckmarkUrl()
        loadBranchData()
    }
    
    func loadSpecialistData() {
        guard let customColor = record.custom_color else { return }
        let ref = Database.database().reference(withPath: "specialists")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                for (_, value) in dict {
                    if let spec = value as? [String: Any],
                       let color = spec["color"] as? String,
                       let fullName = spec["full_name"] as? String,
                       let specialistRole = spec["specialistRole"] as? String,
                       color == customColor {
                        firebaseSpecialist = FirebaseSpecialist(fullName: fullName,
                                                                avatar: spec["avatar_big"] as? String,
                                                                specialistRole: specialistRole)
                        break
                    }
                }
            }
        }
    }
    
    func loadCheckmarkUrl() {
        let ref = Database.database().reference(withPath: "specialists/checkmarkUrl")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let url = snapshot.value as? String {
                checkmarkUrl = url
            }
        }
    }
    
    func loadBranchData() {
        let ref = Database.database().reference(withPath: "branches/\(record.company_id)")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let branchData = snapshot.value as? [String: Any] {
                branchName = branchData["branch_name"] as? String
                branchAddress = branchData["address"] as? String
                mapImage = branchData["map_image"] as? String
            }
        }
    }
    
    // MARK: - Вспомогательные функции
    
    func calculateEndTime(start: Date, duration: Int) -> Date {
        return start.addingTimeInterval(TimeInterval(duration))
    }
    
    func openLink(url: String) {
        if let url = URL(string: url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция для подтверждения записи (PUT запрос)
    func confirmRecord() {
        print("Вызов функции confirmRecord() для записи id: \(record.id)")
        guard let visitId = record.visit_id else {
            print("visit_id отсутствует для записи id: \(record.id)")
            return
        }
        let recordId = record.id
        let apiUrl = "https://api.yclients.com/api/v1/visits/\(visitId)/\(recordId)"
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        
        guard let url = URL(string: apiUrl) else {
            print("Неверный URL: \(apiUrl)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        let servicesArray: [[String: Any]] = record.services?.map { service in
            return [
                "id": service.id,
                "title": service.title,
                "cost": service.cost,
                "record_id": record.id
            ]
        } ?? []
        
        let body: [String: Any] = [
            "attendance": 2,
            "comment": "Запись подтверждена пользователем",
            "services": servicesArray
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("Ошибка сериализации body: \(body)")
            return
        }
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка подтверждения записи: \(error)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Запись id \(record.id) успешно подтверждена (HTTP статус 200)")
                    viewModel.showModal = false
                    // Вместо передачи phone, вызываем refreshData(), который сам должен извлекать номер телефона
                    viewModel.refreshData()
                } else {
                    print("Ошибка подтверждения записи: неожиданный статус ответа")
                    if let data = data, let responseBody = try? JSONSerialization.jsonObject(with: data) {
                        print("Response body: \(responseBody)")
                    }
                }
            }
        }.resume()
    }
    
    // Функция для удаления записи (DELETE запрос)
    func confirmDelete() {
        let recordId = record.id
        let companyId = record.company_id
        let apiUrl = "https://api.yclients.com/api/v1/record/\(companyId)/\(recordId)"
        let accessToken = "88fnh8jbmt44er5y28nj"
        let accessUserToken = "9d241fb00061c17a5e2e76a23b214b20"
        
        guard let url = URL(string: apiUrl) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken), User \(accessUserToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка при удалении записи: \(error)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    print("Запись \(record.id) успешно удалена")
                    viewModel.showModal = false
                    // Вызываем refreshData() без параметров
                    viewModel.refreshData()
                }
            }
        }.resume()
    }
}
