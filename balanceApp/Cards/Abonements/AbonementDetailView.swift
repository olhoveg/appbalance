import SwiftUI
import Foundation
import FirebaseDatabase

struct AbonementDetailView: View {
    @State var abonement: Abonement
    @State private var isLoading: Bool = false
    @State private var visitVMById: [Int: VisitVM] = [:]
    @State private var selectedVisit: SelectedVisit? = nil
    @State private var loadingVisitIds: Set<Int> = []
    @State private var recordIdByVisitId: [Int: Int] = [:]
    @State private var companyIdByVisitId: [Int: Int] = [:]
    @State private var refreshTrigger = 0
    @State private var selectedService: ServiceInfo? = nil
    
    // Для загрузки изображения абонемента
    @EnvironmentObject var imageCache: ImageCache
    @StateObject private var imageLoader: AbonementImageLoader
    @State private var loadedImage: UIImage? = nil
    @State private var isImageLoaded: Bool = false

    // MARK: - Visit view model
    // MARK: - Selection wrapper for .sheet(item:)
    struct SelectedVisit: Identifiable { let id: Int }

    init(abonement: Abonement) {
        self.abonement = abonement
        _imageLoader = StateObject(wrappedValue: AbonementImageLoader(key: abonement.type.title))
    }

    // MARK: - Updated Visit API decoders based on actual response
    private struct VisitResponse: Decodable { 
        let success: Bool
        let data: VisitData?
    }
    
    private struct VisitData: Decodable {
        let attendance: Int
        let datetime: String
        let comment: Int
        let records: [VisitRecord]
    }
    
    private struct VisitRecord: Decodable {
        let id: Int
        let company_id: Int
        let staff_id: Int
        let services: [VisitService]
        let staff: Staff
        let client: Client
        let date: String
        let datetime: String
        let seance_length: Int
        let length: Int
        let visit_id: Int
        let payment_status: Int
    }
    
    private struct Staff: Decodable { 
        let id: Int
        let name: String
        let specialization: String
    }
    
    private struct Client: Decodable {
        let id: Int
        let name: String
        let phone: String
    }
    
    private struct VisitService: Decodable { 
        let id: Int
        let title: String
        let cost: Double
        let cost_to_pay: Double
        let amount: Int
    }

    // MARK: - Record (Запись) API decoders
    private struct RecordAPIResponse: Decodable { let success: Bool; let data: RecordOne? }
    private struct RecordOne: Decodable {
        let id: Int
        let company_id: Int
        let datetime: String // e.g. 2019-01-01T12:00:00+09:00
        let length: Int
        let staff: Staff
        let services: [VisitService]
        let visit_id: String?
    }

    // MARK: - Lightweight decoder to extract item_record_id from transactions
    private struct TxLiteEnvelope: Decodable { let success: Bool; let data: [TxLite] }
    private struct TxLite: Decodable {
        let visit_id: Int
        let item_record_id: Int?
        let abonement_id: Int?
        let type_id: Int
    }
    
    // MARK: - Transaction API decoders
    private struct TransactionAPIResponse: Decodable { let success: Bool; let data: [AppTransaction] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Верхняя секция с фото и основной информацией
                VStack(spacing: 16) {
                    // Фото абонемента
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            Color.gray.opacity(0.15)
                            
                            if let url = imageLoader.imageUrl, !url.isEmpty {
                                if let entry = imageCache.cachedImages[url] {
                                    Image(uiImage: entry.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .opacity(isImageLoaded ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.35), value: isImageLoaded)
                                        .onAppear { isImageLoaded = true }
                                } else if let img = loadedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .opacity(isImageLoaded ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.35), value: isImageLoaded)
                                        .onAppear { isImageLoaded = true }
                                } else {
                                    ProgressView() 
                                        .onAppear {
                                            imageCache.loadImage(from: url) { image in
                                                self.loadedImage = image
                                                withAnimation {
                                                    self.isImageLoaded = true
                                                }
                                            }
                                        }
                                }
                            }
                        }
                        .frame(height: 240)
                        .clipped()
                        
                        // Номер абонемента
                        Text("№ \(abonement.number)")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(8)
                    }
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )
                    
                    // Основная информация
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Абонемент")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            StatusBadge(isActive: abonement.isActive)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            AbonementInfoRow(label: "Тип", value: abonement.type.title)
                            AbonementInfoRow(label: "Баланс", value: displayBalance())
                            AbonementInfoRow(label: "Дата покупки", value: formattedDate(abonement.createdDate))
                            
                            if let expDate = abonement.expirationDate {
                                AbonementInfoRow(label: "Срок окончания", value: formattedDate(expDate))
                            } else if let expText = abonement.expirationText {
                                AbonementInfoRow(label: "Срок окончания", value: expText)
                            } else {
                                AbonementInfoRow(label: "Срок окончания", value: "Бессрочный")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Секция с услугами абонемента
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Услуги абонемента")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Показываем общее количество использованных сеансов
                        let totalUsedSessions = getTotalUsedSessions()
                        if totalUsedSessions > 0 {
                            Text("Использовано: \(totalUsedSessions)")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    

                    

                    
                    if let balanceString = abonement.balanceString, !balanceString.isEmpty {
                        // Используем balanceString для извлечения названий услуг
                        let services = parseServicesFromBalanceString(balanceString)
                        

                        
                        VStack(spacing: 8) {
                            ForEach(services.indices, id: \.self) { index in
                                let service = services[index]
                                ServiceRow(
                                    serviceNumber: index + 1,
                                    sessionsCount: service.count,
                                    serviceType: service.name,
                                    categoryTitle: service.name,
                                    usedSessionsCount: getUsedSessionsCount(for: service.name),
                                    onTap: {
                                        selectedService = service
                                    }
                                )
                            }
                        }
                    } else if let balanceContainer = abonement.balanceContainer, !balanceContainer.links.isEmpty {
                        // Используем balanceContainer только если там есть конкретные услуги (service.title)
                        let servicesWithNames = balanceContainer.links.filter { $0.service?.title != nil }
                        
                        if !servicesWithNames.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(servicesWithNames.indices, id: \.self) { index in
                                    let link = servicesWithNames[index]
                                    ServiceRow(
                                        serviceNumber: index + 1,
                                        sessionsCount: link.count,
                                        serviceType: link.service!.title,
                                        categoryTitle: link.service!.title,
                                        usedSessionsCount: getUsedSessionsCount(for: link.service!.title),
                                        onTap: {
                                            selectedService = ServiceInfo(name: link.service!.title, count: link.count)
                                        }
                                    )
                                }
                            }
                        } else {
                            // Если нет конкретных услуг, показываем общее количество
                            if let unitedBalance = abonement.united_balance_services_count {
                                ServiceRow(
                                    serviceNumber: 1,
                                    sessionsCount: unitedBalance,
                                    serviceType: abonement.type.title,
                                    categoryTitle: abonement.type.title,
                                    usedSessionsCount: getUsedSessionsCount(for: abonement.type.title),
                                    onTap: {
                                        selectedService = ServiceInfo(name: abonement.type.title, count: unitedBalance)
                                    }
                                )
                            } else {
                                Text("Информация об услугах недоступна")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    } else if let unitedBalance = abonement.united_balance_services_count {
                        ServiceRow(
                            serviceNumber: 1,
                            sessionsCount: unitedBalance,
                            serviceType: abonement.type.title,
                            categoryTitle: abonement.type.title,
                            usedSessionsCount: getUsedSessionsCount(for: abonement.type.title),
                            onTap: {
                                selectedService = ServiceInfo(name: abonement.type.title, count: unitedBalance)
                            }
                        )
                    } else {
                        Text("Информация об услугах недоступна")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // История списаний
                VStack(alignment: .leading, spacing: 12) {
                    Text("История использования")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let tx = abonement.transactions, !tx.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(tx.enumerated()), id: \.element.id) { i, t in
                                AbonementTransactionRow(
                                    transaction: t,
                                    visitVM: visitVMById[t.visitId],
                                    balanceBefore: calculateBalanceBefore(transactions: tx, currentIndex: i),
                                    balanceAfter: calculateBalanceAfter(transactions: tx, currentIndex: i, visitVM: visitVMById[t.visitId]),
                                    onTap: {
                                        self.selectedVisit = SelectedVisit(id: t.visitId)
                                    }
                                )
                            }
                        }
                    } else {
                        Text("Нет использований по абонементу")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            fetchTransactions()
            // Загружаем изображение если нужно
            if imageLoader.imageUrl == nil {
                imageLoader.loadImage()
            }
        }
        .sheet(item: $selectedVisit) { sel in
            let vid = sel.id
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Заголовок
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Детали визита")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Визит #\(vid)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 10)

                        if let vm = visitVMById[vid] {
                            // Основная информация
                            VStack(spacing: 16) {
                                // Дата и время
                                DetailCard(title: "Дата и время", icon: "calendar") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        DetailRow(label: "Дата", value: formattedDate(vm.startTime))
                                        DetailRow(label: "Начало", value: formatTime(vm.startTime))
                                        DetailRow(label: "Окончание", value: formatTime(vm.endTime))
                                        DetailRow(label: "Длительность", value: formatDuration(vm.startTime, vm.endTime))
                                    }
                                }
                                
                                // Услуга и специалист
                                DetailCard(title: "Услуга", icon: "star.fill") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        DetailRow(label: "Название", value: vm.serviceTitle.isEmpty ? "—" : vm.serviceTitle)
                                        DetailRow(label: "Специалист", value: vm.specialistName)
                                        if let cost = vm.serviceCost {
                                            DetailRow(label: "Стоимость", value: "\(Int(cost)) ₽")
                                        }
                                    }
                                }
                                
                                // Дополнительная информация
                                DetailCard(title: "Информация", icon: "info.circle") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        DetailRow(label: "ID визита", value: "\(vid)")
                                        DetailRow(label: "Статус", value: "Завершен")
                                    }
                                }
                            }
                        } else if loadingVisitIds.contains(vid) {
                            // Загрузка
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Загружаем детали визита...")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                        } else {
                            // Ошибка
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text("Ошибка загрузки")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("Не удалось загрузить детали визита")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Закрыть") {
                    selectedVisit = nil
                })
            }
            .onAppear { ensureVisitLoaded(vid) }
            .onChange(of: visitVMById[vid] != nil) { _ in /* trigger rebuild */ }
        }
        .sheet(item: $selectedService) { service in
            AbonementServiceDetailView(
                serviceName: service.name,
                sessionsCount: service.count,
                usedSessionsCount: getUsedSessionsCount(for: service.name)
            )
        }
    }
    
    private func ensureVisitLoaded(_ visitId: Int) {
        if visitVMById[visitId] != nil { return }
        if loadingVisitIds.contains(visitId) { return }
        loadingVisitIds.insert(visitId)
        fetchVisitByIdFallback(visitId: visitId)
    }

    private func fetchVisitDetailsForTransactions() {
        guard let tx = abonement.transactions, !tx.isEmpty else { return }

        for t in tx {
            let visitId = t.visitId
            if visitVMById[visitId] != nil { continue }
            // Получаем данные визита напрямую
            self.fetchVisitByIdFallback(visitId: visitId)
        }
    }

    private func fetchRecord(companyId: Int, recordId: Int, visitId: Int) {
        let urlString = "https://api.yclients.com/api/v1/record/\(companyId)/\(recordId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        let authHeader = "Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ Record fetch error for recordId=\(recordId): \(error.localizedDescription)")
                self.fetchVisitByIdFallback(visitId: visitId)
                return
            }
            guard let data = data else { self.fetchVisitByIdFallback(visitId: visitId); return }

            do {
                let decoder = JSONDecoder()
                let payload = try decoder.decode(RecordAPIResponse.self, from: data)
                guard let rec = payload.data else {
                    print("ℹ️ No record data for recordId=\(recordId), fallback to /visits")
                    self.fetchVisitByIdFallback(visitId: visitId)
                    return
                }
                let start = iso.date(from: rec.datetime) ?? Date()
                let end = start.addingTimeInterval(TimeInterval(rec.length))
                let service = rec.services.first
                let vm = VisitVM(
                    serviceTitle: service?.title ?? "",
                    specialistName: rec.staff.name,
                    startTime: start,
                    endTime: end,
                    serviceCost: service?.cost,
                    sessionsCount: service?.amount
                )
                DispatchQueue.main.async {
                    self.visitVMById[visitId] = vm
                    self.refreshTrigger += 1
                }
            } catch {
                print("❌ Record decode error for recordId=\(recordId): \(error)")
                if let json = String(data: data, encoding: .utf8) {
                    print("Raw record JSON (recordId=\(recordId)):\n\(json)")
                }
                self.fetchVisitByIdFallback(visitId: visitId)
            }
        }.resume()
    }

    private func fetchVisitByIdFallback(visitId: Int) {
        let urlString = "https://api.yclients.com/api/v1/visits/\(visitId)"
        guard let url = URL(string: urlString) else { 
            DispatchQueue.main.async { self.loadingVisitIds.remove(visitId) }
            return 
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        let authHeader = "Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        print("⏳ Fetching visit id=\(visitId)")

        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer {
                DispatchQueue.main.async { self.loadingVisitIds.remove(visitId) }
            }
            
            if let error = error {
                print("❌ Visit fetch error for id=\(visitId): \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP Status for visit \(visitId): \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP error for visit \(visitId): \(httpResponse.statusCode)")
                    return
                }
            }
            
            guard let data = data else { 
                print("❌ No data received for visit \(visitId)")
                return 
            }

            do {
                let decoder = JSONDecoder()
                let payload = try decoder.decode(VisitResponse.self, from: data)
                
                guard let visitData = payload.data, !visitData.records.isEmpty else {
                    print("ℹ️ No visit data or empty records for id=\(visitId)")
                    if let json = String(data: data, encoding: .utf8) { 
                        print("Raw visit JSON (id=\(visitId)):\n\(json)") 
                    }
                    return
                }
                
                // Берем первую запись из records
                let record = visitData.records[0]
                let start = iso.date(from: record.datetime) ?? Date()
                let end = start.addingTimeInterval(TimeInterval(record.length))
                let service = record.services.first
                
                let vm = VisitVM(
                    serviceTitle: service?.title ?? "",
                    specialistName: record.staff.name,
                    startTime: start,
                    endTime: end,
                    serviceCost: service?.cost,
                    sessionsCount: service?.amount
                )
                
                DispatchQueue.main.async {
                    self.companyIdByVisitId[visitId] = record.company_id
                    self.visitVMById[visitId] = vm
                    self.refreshTrigger += 1
                }
                
                print("✅ Successfully loaded visit \(visitId): \(vm.serviceTitle) at \(vm.startTime)")
                
            } catch {
                print("❌ Visit decode error for id=\(visitId): \(error)")
                if let json = String(data: data, encoding: .utf8) {
                    print("Raw visit JSON (id=\(visitId)):\n\(json)")
                }
            }
        }.resume()
    }

    private func fetchTransactions() {
        let chainId = "415038"

        print("\n==============================")
        print("🔎 fetchTransactions() start")
        print("Abonement id=\(self.abonement.id), number=\(self.abonement.number)")
        print("createdDate=\(self.abonement.createdDate)")
        if let exp = self.abonement.expirationDate {
            print("expirationDate=\(exp)")
        } else {
            print("expirationDate=nil (бессрочный или не задан)")
        }

        // Диапазон дат: с даты покупки абонемента до сегодняшнего дня
        let dfDateParam = DateFormatter()
        dfDateParam.dateFormat = "yyyy-MM-dd"

        let startDate = self.abonement.createdDate
        let endDate = Date()

        let createdAfter = dfDateParam.string(from: startDate)
        let createdBefore = dfDateParam.string(from: endDate)

        // types[]=9 — использование абонемента, types[]=10 — перерасчет по абонементу (для диагностики)
        let urlString = "https://api.yclients.com/api/v1/chain/\(chainId)/loyalty/transactions?created_after=\(createdAfter)&created_before=\(createdBefore)&types[]=9&types[]=10&count=100&page=1"

        print("Request URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for loyalty transactions")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        // В лог токен полностью не выводим, чтобы не светить
        let authHeader = "Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        print("Headers: Accept=application/vnd.yclients.v2+json, Content-Type=application/json, Authorization=<hidden>")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error for abonement \(self.abonement.id): \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP Status for abonement \(self.abonement.id): \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received for abonement \(self.abonement.number)")
                return
            }

            print("📦 Response bytes: \(data.count)")

            // Сырой ответ для отладки (можно закомментировать, если шумно)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw transactions JSON for abonement \(self.abonement.number):\n\(jsonString)")
            }

            // Дополнительно оставляем только операции использования абонемента (typeId == 9)
            do {
                let decoder = JSONDecoder()
                let dfISO = DateFormatter()
                dfISO.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                decoder.dateDecodingStrategy = .formatted(dfISO)

                let response = try decoder.decode(TransactionAPIResponse.self, from: data)
                let all = response.data
                print("✅ Decoded transactions count: \(all.count)")

                // Диагностика: распределение по typeId
                let typeHistogram = Dictionary(grouping: all, by: { $0.typeId }).mapValues { $0.count }
                print("📊 typeId histogram: \(typeHistogram)")



                // Фильтруем по текущему абонементу
                let filtered = all.filter { $0.abonementId == self.abonement.id }
                print("🧮 Filtered by abonementId=\(self.abonement.id): \(filtered.count)")
                
                // Отладочная информация: показываем все abonement_id в ответе
                let uniqueAbonementIds = Set(all.compactMap { $0.abonementId })
                print("🔍 All abonement_ids in response: \(Array(uniqueAbonementIds).sorted())")
                
                if filtered.isEmpty {
                    print("⚠️ No transactions found for abonement \(self.abonement.id)")
                    print("📋 Looking for transactions with abonement_id: \(self.abonement.id)")
                }

                // Дополнительно оставляем только операции использования абонемента (typeId == 9)
                let filtered9 = filtered.filter { $0.typeId == 9 }
                print("🎯 After typeId==9 filter: \(filtered9.count)")

                // 🧭 Построим карту visitId -> recordId (item_record_id) на основе исходного JSON
                do {
                    let lite = try JSONDecoder().decode(TxLiteEnvelope.self, from: data)
                    var map: [Int: Int] = [:]
                    for tx in lite.data where tx.type_id == 9 && tx.abonement_id == self.abonement.id {
                        if let rid = tx.item_record_id { map[tx.visit_id] = rid }
                    }
                    print("🗺️ Built recordIdByVisitId map entries: \(map.count)")
                    DispatchQueue.main.async {
                        self.recordIdByVisitId = map
                    }
                } catch {
                    print("⚠️ Failed to build recordIdByVisitId map: \(error)")
                }

                DispatchQueue.main.async {
                    self.abonement.transactions = filtered9
                    self.fetchVisitDetailsForTransactions()
                    // Обновляем UI для пересчета использованных сеансов
                    self.refreshTrigger += 1
                }
            } catch {
                print("❌ Transactions decode error for abonement \(self.abonement.number): \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❗️ Decode failed on JSON:\n\(jsonString)")
                }
            }
        }.resume()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    private func formatDuration(_ start: Date, _ end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }

    // MARK: - Helper functions
    private func displayBalance() -> String {
        if let balanceStr = abonement.balanceString {
            let pattern = "\\(x(\\d+)\\)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: balanceStr, range: NSRange(location: 0, length: balanceStr.utf16.count)),
               let range = Range(match.range(at: 1), in: balanceStr) {
                let countStr = String(balanceStr[range])
                if let count = Int(countStr) {
                    return formatBalance(count: count, title: abonement.type.title)
                }
            }
        }
        
        if let count = abonement.united_balance_services_count {
            return formatBalance(count: count, title: abonement.type.title)
        }
        
        if let container = abonement.balanceContainer {
            let total = container.links.reduce(0) { $0 + $1.count }
            if total > 0 {
                return formatBalance(count: total, title: abonement.type.title)
            }
        }
        
        return "0"
    }
    
    private func formatBalance(count: Int, title: String) -> String {
        let lowerTitle = title.lowercased()
        let isSolarium = lowerTitle.contains("солярий")
        
        if isSolarium {
            return "\(count) \(pluralizeMinutes(count: count))"
        } else {
            return "\(count) \(pluralizeSessions(count: count))"
        }
    }
    
    private func pluralizeSessions(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "сеансов"
        } else if rem10 == 1 {
            return "сеанс"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "сеанса"
        } else {
            return "сеансов"
        }
    }
    
    private func pluralizeMinutes(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "минут"
        } else if rem10 == 1 {
            return "минута"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "минуты"
        } else {
            return "минут"
        }
    }
    
    private func calculateBalanceBefore(transactions: [AppTransaction], currentIndex: Int) -> Int {
        var balance = abonement.initialBalance ?? abonement.balance + transactions.reduce(0) { sum, transaction in 
            let visitVM = visitVMById[transaction.visitId]
            return sum + (visitVM?.sessionsCount ?? 1)
        }
        
        for i in 0..<currentIndex {
            let transaction = transactions[i]
            let visitVM = visitVMById[transaction.visitId]
            balance -= (visitVM?.sessionsCount ?? 1)
        }
        
        return balance
    }
    
    private func calculateBalanceAfter(transactions: [AppTransaction], currentIndex: Int, visitVM: VisitVM?) -> Int {
        let balanceBefore = calculateBalanceBefore(transactions: transactions, currentIndex: currentIndex)
        let sessionsUsed = visitVM?.sessionsCount ?? 1
        return balanceBefore - sessionsUsed
    }
    
    private func getUsedSessionsCount(for serviceName: String) -> Int {
        // Проверяем, загружены ли транзакции
        guard let transactions = abonement.transactions, !transactions.isEmpty else { 
            print("⚠️ No transactions available for service: \(serviceName)")
            return 0 
        }
        
        print("🔍 Checking \(transactions.count) transactions for service: \(serviceName)")
        print("📋 Transaction IDs: \(transactions.map { $0.id })")
        
        var usedCount = 0
        for transaction in transactions {
            // Используем данные из visitVMById как основной источник
            if let visitVM = visitVMById[transaction.visitId] {
                // Проверяем несколько источников названия услуги
                let possibleServiceTitles = [
                    visitVM.serviceTitle,
                    // Также проверяем название из visitDetails если доступно
                    transaction.visitDetails?.serviceTitle
                ].compactMap { $0 }
                
                for serviceTitle in possibleServiceTitles {
                    let normalizedServiceName = serviceName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalizedServiceTitle = serviceTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Проверяем точное совпадение или если название услуги содержит ключевые слова
                    if normalizedServiceTitle == normalizedServiceName ||
                       normalizedServiceTitle.contains(normalizedServiceName) ||
                       normalizedServiceName.contains(normalizedServiceTitle) {
                        let sessionsUsed = visitVM.sessionsCount ?? 1
                        usedCount += sessionsUsed
                        break
                    }
                }
            }
        }
        
        return usedCount
    }
    
    private func getTotalUsedSessions() -> Int {
        // Проверяем, загружены ли транзакции
        guard let transactions = abonement.transactions, !transactions.isEmpty else { 
            return 0 
        }
        
        var totalUsed = 0
        for transaction in transactions {
            if let visitVM = visitVMById[transaction.visitId] {
                totalUsed += visitVM.sessionsCount ?? 1
            }
        }
        
        return totalUsed
    }
}

// MARK: - Service Row Component
struct ServiceRow: View {
    let serviceNumber: Int
    let sessionsCount: Int
    let serviceType: String
    let categoryTitle: String?
    let usedSessionsCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getServiceTitle(serviceNumber: serviceNumber, serviceType: serviceType, categoryTitle: categoryTitle))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(formatServiceCount(sessionsCount, serviceType: serviceType))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Вместо галочки показываем количество использованных сеансов
                if usedSessionsCount > 0 {
                    Text("\(usedSessionsCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .clipShape(Circle())
                } else {
                    Text("0")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getServiceTitle(serviceNumber: Int, serviceType: String, categoryTitle: String?) -> String {
        // Используем название категории из API или название услуги
        if let categoryTitle = categoryTitle, !categoryTitle.isEmpty {
            return categoryTitle
        }
        
        // Если категория недоступна, используем переданное название услуги
        return serviceType
    }
    
    private func formatServiceCount(_ count: Int, serviceType: String) -> String {
        // Показываем общее количество сеансов в абонементе
        return "\(count) \(pluralizeSessions(count: count))"
    }
    
    private func pluralizeSessions(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "сеансов"
        } else if rem10 == 1 {
            return "сеанс"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "сеанса"
        } else {
            return "сеансов"
        }
    }
    
    private func pluralizeMinutes(count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        
        if rem100 >= 11 && rem100 <= 14 {
            return "минут"
        } else if rem10 == 1 {
            return "минута"
        } else if rem10 >= 2 && rem10 <= 4 {
            return "минуты"
        } else {
            return "минут"
        }
    }
}

// MARK: - Transaction Row Component
struct AbonementTransactionRow: View {
    let transaction: AppTransaction
    let visitVM: VisitVM?
    let balanceBefore: Int
    let balanceAfter: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Использование абонемента")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Списано:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedDate(transaction.date))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        HStack(spacing: 8) {
                            Text("Визит:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(visitVM?.startTime != nil ? formattedDate(visitVM!.startTime) : "—")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("#\(transaction.visitId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Spacer()
                
                // Баланс до и после
                HStack(spacing: 6) {
                    Text("\(balanceBefore)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("→")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(balanceAfter)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Helper Views
struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.headline)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct AbonementInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct StatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        Text(isActive ? "Активен" : "Неактивен")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(isActive ? .white : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.green : Color.red)
            .cornerRadius(8)
    }
}

// MARK: - Helper Functions
extension AbonementDetailView {
    private func parseServicesFromBalanceString(_ balanceString: String) -> [ServiceInfo] {
        var services: [ServiceInfo] = []
        
        // Разбиваем строку по запятым
        let components = balanceString.components(separatedBy: ", ")
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Ищем количество в скобках (x5)
            let countPattern = "\\(x(\\d+)\\)"
            let countRegex = try! NSRegularExpression(pattern: countPattern)
            let countMatches = countRegex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
            
            var count = 1
            var serviceName = trimmed
            
            if let match = countMatches.first {
                let countRange = Range(match.range(at: 1), in: trimmed)!
                count = Int(trimmed[countRange]) ?? 1
                serviceName = trimmed.replacingOccurrences(of: countPattern, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Пропускаем пустые названия
            if !serviceName.isEmpty {
                // Если это раздел, показываем конкретные услуги
                if serviceName == "Разминания" {
                    // Добавляем конкретные услуги разминания
                    let massageServices = [
                        "Разминание головы",
                        "Разминание шеи", 
                        "Разминание плеч",
                        "Разминание спины",
                        "Разминание рук",
                        "Разминание ног",
                        "Разминание стоп"
                    ]
                    
                    // Добавляем услуги в зависимости от количества
                    for i in 0..<min(count, massageServices.count) {
                        services.append(ServiceInfo(name: massageServices[i], count: 1))
                    }
                } else if serviceName == "SPA процедуры" {
                    // Добавляем конкретные SPA услуги
                    let spaServices = [
                        "SPA-массаж",
                        "Ароматерапия",
                        "Гидромассаж",
                        "Талассотерапия"
                    ]
                    
                    for i in 0..<min(count, spaServices.count) {
                        services.append(ServiceInfo(name: spaServices[i], count: 1))
                    }
                } else {
                    // Для других услуг оставляем как есть
                    services.append(ServiceInfo(name: serviceName, count: count))
                }
            }
        }
        
        return services
    }
}

struct ServiceInfo: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

// MARK: - Service Detail View
struct AbonementServiceDetailView: View {
    let serviceName: String
    let sessionsCount: Int
    let usedSessionsCount: Int
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var serviceImageUrl: String? = nil
    @State private var loadedImage: UIImage? = nil
    @State private var isLoadingImage = false
    
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Изображение услуги
                    ZStack {
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: 250)
                                .clipped()
                        } else if isLoadingImage {
                            ProgressView()
                                .frame(width: cardWidth, height: 250)
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: cardWidth, height: 250)
                        }
                    }
                    .frame(width: cardWidth, height: 250)
                    .clipped()
                    .cornerRadius(12)
                    
                    // Основная информация
                    VStack(alignment: .leading, spacing: 12) {
                        Text(serviceName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Длительность: \(getServiceDuration(serviceName))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Количество сеансов: \(sessionsCount)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if usedSessionsCount > 0 {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Использовано")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("\(usedSessionsCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Подробное описание
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Описание услуги")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(getDetailedServiceDescription(serviceName))
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Показания и противопоказания
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Показания и рекомендации")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ServiceInfoRow(title: "Показания", value: getServiceIndications(serviceName))
                            ServiceInfoRow(title: "Противопоказания", value: getServiceContraindications(serviceName))
                            ServiceInfoRow(title: "Рекомендации", value: getServiceRecommendations(serviceName))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Техники и особенности
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Техники и особенности")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(getServiceTechniques(serviceName))
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Детали услуги")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                }
            )
        }
        .onAppear {
            loadServiceImage()
        }
    }
    
    private func loadServiceImage() {
        Task {
            let imageUrl = await getServiceImageUrl(serviceName)
            await MainActor.run {
                serviceImageUrl = imageUrl
                if let url = imageUrl {
                    loadImage(from: url)
                }
            }
        }
    }
    
    private func loadImage(from urlString: String) {
        guard !urlString.isEmpty else { return }
        
        // Проверяем кэш
        if let cached = ServicesImageCache.shared.cachedImages[urlString]?.image {
            self.loadedImage = cached
            return
        }
        
        isLoadingImage = true
        ServicesImageCache.shared.loadImage(from: urlString) { image in
            DispatchQueue.main.async {
                self.loadedImage = image
                self.isLoadingImage = false
            }
        }
    }
    
    private func getServiceImageUrl(_ serviceName: String) async -> String? {
        await withCheckedContinuation { continuation in
            let dataRef = Database.database().reference(withPath: "services")
            dataRef.observeSingleEvent(of: .value, with: { snapshot in
                var imageUrl: String? = nil
                
                // Создаем маппинг названий услуг для более точного сопоставления
                let serviceMapping: [String: [String]] = [
                    "Разминание головы": ["Разминание головы", "Массаж головы", "Головной массаж"],
                    "Разминание шеи": ["Разминание шеи", "Массаж шеи", "Шейный массаж"],
                    "Разминание плеч": ["Разминание плеч", "Массаж плеч", "Плечевой массаж"],
                    "Разминание спины": ["Разминание спины", "Массаж спины", "Спинной массаж"],
                    "Разминание рук": ["Разминание рук", "Массаж рук", "Ручной массаж"],
                    "Разминание ног": ["Разминание ног", "Массаж ног", "Ножной массаж"],
                    "Разминание стоп": ["Разминание стоп", "Массаж стоп", "Стопный массаж"],
                    "Классический массаж лица": ["Классический массаж лица", "Массаж лица", "Лицевой массаж"],
                    "Детский оздоровительный (30 мин)": ["Детский оздоровительный", "Детский массаж", "Детский оздоровительный (30 мин)"],
                    "Антицел бёдер": ["Антицеллюлитный массаж бедер", "Антицел бёдер", "Антицеллюлитный массаж"],
                    "Антицел живота": ["Антицеллюлитный массаж живота", "Антицел живота", "Антицеллюлитный массаж"],
                    "Антицел рук": ["Антицеллюлитный массаж рук", "Антицел рук", "Антицеллюлитный массаж"]
                ]
                
                // Получаем возможные названия для данной услуги
                let possibleNames = serviceMapping[serviceName] ?? [serviceName]
                
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    if let childData = child.value as? [String: Any],
                       let childTitle = childData["title"] as? String,
                       let img = childData["imageUrl"] as? String {
                        
                        // Проверяем точное совпадение или совпадение с возможными названиями
                        if possibleNames.contains(childTitle) || childTitle.contains(serviceName) || serviceName.contains(childTitle) {
                            imageUrl = img
                            print("Found image for \(serviceName) with title: \(childTitle)")
                            break
                        }
                    }
                }
                
                print("Fetched imageUrl for \(serviceName): \(imageUrl ?? "nil")")
                continuation.resume(returning: imageUrl)
            }, withCancel: { error in
                print("Error fetching image by service title: \(error)")
                continuation.resume(returning: nil)
            })
        }
    }
    
    private func getDetailedServiceDescription(_ serviceName: String) -> String {
        switch serviceName {
        case "Разминание головы":
            return "Профессиональный массаж головы - это комплексная процедура, направленная на глубокое расслабление мышц головы, лица и шеи. Наши специалисты используют специальные техники, которые помогают снять напряжение, улучшить кровообращение и лимфоток в области головы.\n\nМассаж включает работу с височными мышцами, лобной областью, затылочной частью и шейно-воротниковой зоной. Это помогает не только расслабиться, но и улучшить концентрацию внимания, снять головную боль и мигрень, а также нормализовать сон."
        case "Разминание шеи":
            return "Специализированный массаж шейно-воротниковой зоны - это целенаправленная работа с мышцами шеи, плеч и верхней части спины. Данная процедура особенно эффективна для людей, ведущих малоподвижный образ жизни или работающих за компьютером.\n\nМассаж включает глубокую проработку трапециевидных мышц, лестничных мышц и мышц-разгибателей шеи. Это помогает устранить мышечные зажимы, улучшить подвижность шейного отдела позвоночника, снять напряжение и предотвратить развитие остеохондроза."
        case "Разминание плеч":
            return "Массаж плечевого пояса направлен на расслабление и восстановление мышц плеч, верхней части спины и рук. Эта процедура особенно полезна после физических нагрузок, спортивных тренировок или длительной работы в статичном положении.\n\nСпециалист прорабатывает дельтовидные мышцы, трапециевидные мышцы и мышцы-вращатели плеча. Массаж помогает снять мышечное напряжение, улучшить кровообращение, восстановить подвижность суставов и предотвратить развитие болевого синдрома."
        case "Разминание спины":
            return "Комплексный массаж спины - это полноценная процедура, охватывающая всю поверхность спины от шеи до поясницы. Наши специалисты используют различные техники массажа, адаптированные под индивидуальные потребности клиента.\n\nМассаж включает работу с поверхностными и глубокими мышцами спины, межреберными мышцами и мышцами-разгибателями позвоночника. Это помогает снять боль и напряжение, улучшить осанку, укрепить мышечный корсет и восстановить подвижность позвоночника."
        case "Разминание рук":
            return "Массаж рук от плеч до кистей - это комплексная процедура, направленная на расслабление и восстановление мышц верхних конечностей. Массаж особенно эффективен после физических нагрузок, спортивных тренировок или длительной работы руками.\n\nПроцедура включает проработку мышц плеч, предплечий и кистей. Специалист использует различные техники для улучшения кровообращения, снятия мышечного напряжения, восстановления подвижности суставов и снятия усталости."
        case "Разминание ног":
            return "Массаж ног - это комплексная процедура, охватывающая мышцы бедер, голеней и стоп. Данный вид массажа особенно полезен после физических нагрузок, длительной ходьбы или стоячей работы.\n\nМассаж включает проработку квадрицепсов, икроножных мышц, мышц стопы и голени. Это помогает снять усталость, улучшить кровообращение, восстановить мышечный тонус и предотвратить развитие варикозной болезни."
        case "Разминание стоп":
            return "Специализированный массаж стоп - это процедура, направленная на расслабление и восстановление мышц стопы, улучшение кровообращения и лимфотока. Массаж стоп особенно эффективен для снятия усталости и напряжения.\n\nПроцедура включает работу с подошвенной поверхностью стопы, пальцами ног и голеностопным суставом. Специалист использует техники рефлексотерапии, воздействуя на активные точки стопы, что помогает улучшить работу внутренних органов и снять общее напряжение."
        case "Классический массаж лица":
            return "Профессиональный массаж лица - это процедура, направленная на улучшение кровообращения, лимфотока и тонуса кожи лица. Массаж помогает сохранить молодость и красоту кожи, а также снять напряжение с мимических мышц.\n\nПроцедура включает работу с лобными, височными, скуловыми мышцами и мышцами вокруг глаз и рта. Специалист использует специальные техники, которые помогают разгладить морщины, улучшить цвет лица, снять отечность и повысить эластичность кожи."
        case "Детский оздоровительный (30 мин)":
            return "Специально разработанный массаж для детей направлен на укрепление иммунитета, улучшение сна и общего самочувствия ребенка. Процедура адаптирована под возрастные особенности детского организма.\n\nМассаж включает мягкие, щадящие техники, направленные на расслабление мышц, улучшение кровообращения и лимфотока. Это помогает укрепить иммунную систему, нормализовать сон, улучшить аппетит и общее самочувствие ребенка."
        case "Антицел бёдер":
            return "Специализированный антицеллюлитный массаж области бедер направлен на борьбу с целлюлитом и улучшение состояния кожи. Процедура включает техники лимфодренажа и антицеллюлитного массажа.\n\nМассаж включает глубокую проработку подкожной жировой клетчатки, улучшение лимфотока и кровообращения. Это помогает уменьшить проявления целлюлита, улучшить тонус кожи, вывести лишнюю жидкость и токсины из организма."
        case "Антицел живота":
            return "Антицеллюлитный массаж области живота направлен на улучшение кровообращения, лимфотока и уменьшение жировых отложений в области живота. Процедура помогает подтянуть кожу и улучшить ее тонус.\n\nМассаж включает работу с мышцами живота, подкожной жировой клетчаткой и кожей. Специалист использует специальные техники, которые помогают активизировать обменные процессы, улучшить кровообращение и лимфоток, что способствует уменьшению жировых отложений."
        case "Антицел рук":
            return "Антицеллюлитный массаж рук направлен на улучшение тонуса кожи, кровообращения и уменьшение жировых отложений в области рук. Процедура помогает подтянуть кожу и улучшить ее состояние.\n\nМассаж включает проработку мышц плеч, предплечий и кистей, а также подкожной жировой клетчатки. Специалист использует техники, которые помогают активизировать обменные процессы, улучшить кровообращение и лимфоток, что способствует уменьшению жировых отложений и улучшению тонуса кожи."
        default:
            return "Профессиональная услуга, выполняемая опытными специалистами с использованием современных техник и качественных материалов. Наши мастера имеют многолетний опыт работы и регулярно повышают свою квалификацию.\n\nКаждая процедура адаптируется под индивидуальные потребности клиента, учитывая его состояние здоровья, возраст и пожелания. Мы используем только качественные материалы и современное оборудование для достижения максимального эффекта."
        }
    }
    
    private func getServiceDuration(_ serviceName: String) -> String {
        switch serviceName {
        case "Детский оздоровительный (30 мин)":
            return "30 минут"
        default:
            return "45-60 минут"
        }
    }
    
    private func getServiceIndications(_ serviceName: String) -> String {
        switch serviceName {
        case "Разминание головы":
            return "Головные боли, мигрень, стресс, бессонница, напряжение в области головы и шеи, усталость глаз, нарушение концентрации внимания."
        case "Разминание шеи":
            return "Боли в шее и плечах, остеохондроз шейного отдела, напряжение мышц, нарушение подвижности шеи, головные боли, связанные с напряжением мышц шеи."
        case "Разминание плеч":
            return "Боли в плечах, напряжение мышц плечевого пояса, последствия травм, спортивные нагрузки, длительная работа в статичном положении."
        case "Разминание спины":
            return "Боли в спине, остеохондроз, сколиоз, нарушение осанки, мышечное напряжение, последствия травм, сидячая работа."
        case "Разминание рук":
            return "Усталость рук, напряжение мышц, последствия физических нагрузок, спортивные травмы, длительная работа руками."
        case "Разминание ног":
            return "Усталость ног, отеки, варикозная болезнь, последствия физических нагрузок, длительная ходьба или стоячая работа."
        case "Разминание стоп":
            return "Усталость стоп, плоскостопие, отеки, нарушение кровообращения, стресс, общее напряжение."
        case "Классический массаж лица":
            return "Старение кожи, морщины, отечность, нарушение кровообращения, стресс, напряжение мимических мышц."
        case "Детский оздоровительный (30 мин)":
            return "Сниженный иммунитет, нарушение сна, плохой аппетит, гиперактивность, стресс, общее недомогание."
        case "Антицел бёдер", "Антицел живота", "Антицел рук":
            return "Целлюлит, дряблость кожи, нарушение кровообращения, лишний вес, отеки, нарушение лимфотока."
        default:
            return "Общее напряжение, стресс, усталость, нарушение кровообращения, мышечные боли."
        }
    }
    
    private func getServiceContraindications(_ serviceName: String) -> String {
        switch serviceName {
        case "Разминание головы", "Разминание шеи", "Разминание плеч", "Разминание спины":
            return "Острые воспалительные процессы, высокая температура, онкологические заболевания, тромбоз, острые травмы, кожные заболевания в области массажа."
        case "Разминание рук", "Разминание ног", "Разминание стоп":
            return "Острые воспалительные процессы, тромбофлебит, варикоз в стадии обострения, острые травмы, кожные заболевания."
        case "Классический массаж лица":
            return "Острые воспалительные процессы на коже лица, акне в стадии обострения, герпес, аллергические реакции, повреждения кожи."
        case "Детский оздоровительный (30 мин)":
            return "Острые инфекционные заболевания, высокая температура, кожные заболевания, острые травмы, индивидуальная непереносимость."
        case "Антицел бёдер", "Антицел живота", "Антицел рук":
            return "Острые воспалительные процессы, тромбофлебит, варикоз в стадии обострения, кожные заболевания, беременность, менструация."
        default:
            return "Острые воспалительные процессы, высокая температура, онкологические заболевания, острые травмы, кожные заболевания."
        }
    }
    
    private func getServiceRecommendations(_ serviceName: String) -> String {
        switch serviceName {
        case "Разминание головы", "Разминание шеи", "Разминание плеч":
            return "Рекомендуется курс из 10-15 процедур для достижения стойкого эффекта. Лучше проводить в вечернее время для расслабления."
        case "Разминание спины":
            return "Рекомендуется курс из 10-15 процедур. Сочетайте с лечебной физкультурой и правильной осанкой для максимального эффекта."
        case "Разминание рук", "Разминание ног", "Разминание стоп":
            return "Рекомендуется после физических нагрузок или длительной работы. Курс из 8-12 процедур для профилактики."
        case "Классический массаж лица":
            return "Рекомендуется курс из 10-15 процедур для достижения видимого эффекта. Сочетайте с правильным уходом за кожей."
        case "Детский оздоровительный (30 мин)":
            return "Рекомендуется курс из 10-15 процедур для укрепления иммунитета. Лучше проводить в первой половине дня."
        case "Антицел бёдер", "Антицел живота", "Антицел рук":
            return "Рекомендуется курс из 15-20 процедур для достижения максимального эффекта. Сочетайте с правильным питанием и физическими упражнениями."
        default:
            return "Рекомендуется консультация со специалистом для подбора оптимального курса и частоты процедур."
        }
    }
    
    private func getServiceTechniques(_ serviceName: String) -> String {
        switch serviceName {
        case "Разминание головы":
            return "Используются техники поглаживания, растирания, разминания и вибрации. Специалист работает с височными, лобными и затылочными мышцами, применяя точечное воздействие на активные точки головы."
        case "Разминание шеи":
            return "Применяются техники классического массажа: поглаживание, растирание, разминание, вибрация. Особое внимание уделяется трапециевидным мышцам и мышцам-разгибателям шеи."
        case "Разминание плеч":
            return "Используются техники глубокого разминания, растирания и вибрации. Прорабатываются дельтовидные мышцы, трапециевидные мышцы и мышцы-вращатели плеча."
        case "Разминание спины":
            return "Применяются все основные техники классического массажа: поглаживание, растирание, разминание, вибрация, поколачивание. Работа ведется с поверхностными и глубокими мышцами спины."
        case "Разминание рук":
            return "Используются техники поглаживания, растирания, разминания и вибрации. Прорабатываются мышцы плеч, предплечий и кистей с учетом анатомических особенностей."
        case "Разминание ног":
            return "Применяются техники классического массажа с акцентом на квадрицепсы, икроножные мышцы и мышцы стопы. Используются приемы лимфодренажа для улучшения кровообращения."
        case "Разминание стоп":
            return "Используются техники рефлексотерапии, точечного массажа и классического массажа. Особое внимание уделяется активным точкам стопы и подошвенной поверхности."
        case "Классический массаж лица":
            return "Применяются мягкие техники поглаживания, растирания и разминания. Работа ведется по массажным линиям лица с учетом анатомии мимических мышц."
        case "Детский оздоровительный (30 мин)":
            return "Используются мягкие, щадящие техники поглаживания и легкого растирания. Массаж адаптирован под возрастные особенности детского организма."
        case "Антицел бёдер", "Антицел живота", "Антицел рук":
            return "Применяются специальные техники антицеллюлитного массажа: глубокое разминание, растирание, лимфодренаж. Работа ведется с подкожной жировой клетчаткой и кожей."
        default:
            return "Используются классические техники массажа, адаптированные под индивидуальные потребности клиента и особенности конкретной процедуры."
        }
    }
}

struct ServiceInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}







