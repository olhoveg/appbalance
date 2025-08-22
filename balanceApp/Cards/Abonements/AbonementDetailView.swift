import SwiftUI
import Foundation

struct AbonementDetailView: View {
    @State var abonement: Abonement
    @State private var isLoading: Bool = false
    @State private var visitVMById: [Int: VisitVM] = [:]
    @State private var selectedVisit: SelectedVisit? = nil
    @State private var loadingVisitIds: Set<Int> = []
    @State private var recordIdByVisitId: [Int: Int] = [:]
    @State private var companyIdByVisitId: [Int: Int] = [:]

    // MARK: - Visit view model
    // MARK: - Selection wrapper for .sheet(item:)
    struct SelectedVisit: Identifiable { let id: Int }
    struct VisitVM {
        let serviceTitle: String
        let specialistName: String
        let startTime: Date
        let endTime: Date
        let serviceCost: Double?
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
        List {
            Section(header: Text("Абонемент")) {
                Text("№ \(abonement.number)")
                Text("ID: \(abonement.id)")
            }
            Section(header: Text("История")) {
                let tx = (abonement.transactions ?? [])
                if !tx.isEmpty {
                    ForEach(tx.indices, id: \.self) { i in
                        let t = tx[i]
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Использование абонемента")
                                    .font(.headline)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text("Списано:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formattedDate(t.date))
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    HStack(spacing: 8) {
                                        let vm = visitVMById[t.visitId]
                                        Text("Визит:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(vm?.startTime != nil ? formattedDate(vm!.startTime) : "—")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("#\(t.visitId)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .onTapGesture {
                            self.selectedVisit = SelectedVisit(id: t.visitId)
                        }
                    }
                } else {
                    Text("Нет использований по абонементу")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            fetchTransactions()
        }
        .sheet(item: $selectedVisit) { sel in
            let vid = sel.id
            VStack(alignment: .leading, spacing: 16) {
                Text("Детали визита").font(.title2).bold()

                if let vm = visitVMById[vid] {
                    HStack { Text("Дата:"); Spacer(); Text(formattedDate(vm.startTime)) }
                    HStack { Text("Начало:"); Spacer(); Text(formatTime(vm.startTime)) }
                    HStack { Text("Окончание:"); Spacer(); Text(formatTime(vm.endTime)) }
                    HStack { Text("Специалист:"); Spacer(); Text(vm.specialistName) }
                    HStack { Text("Услуга:"); Spacer(); Text(vm.serviceTitle.isEmpty ? "—" : vm.serviceTitle) }
                    HStack { Text("Стоимость:"); Spacer(); Text(vm.serviceCost != nil ? "\(Int(vm.serviceCost!)) ₽" : "—") }
                } else if loadingVisitIds.contains(vid) {
                    HStack { ProgressView(); Text("Загружаем визит…") }
                        .foregroundColor(.secondary)
                } else {
                    Text("Ошибка загрузки визита")
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding()
            .onAppear { ensureVisitLoaded(vid) }
            .onChange(of: visitVMById[vid] != nil) { _ in /* trigger rebuild */ }
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
                    serviceCost: service?.cost
                )
                DispatchQueue.main.async {
                    self.visitVMById[visitId] = vm
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
                    serviceCost: service?.cost
                )
                
                DispatchQueue.main.async {
                    self.companyIdByVisitId[visitId] = record.company_id
                    self.visitVMById[visitId] = vm
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

                // Диагностика: первые 10 значений abonementId
                let sample = all.prefix(10)
                for (idx, tx) in sample.enumerated() {
                    print("🔹 tx[#\(idx)] id=\(tx.id) typeId=\(tx.typeId) visitId=\(String(describing: tx.visitId)) abonementId=\(String(describing: tx.abonementId))")
                }

                // Фильтруем по текущему абонементу
                let filtered = all.filter { $0.abonementId == self.abonement.id }
                print("🧮 Filtered by abonementId=\(self.abonement.id): \(filtered.count)")

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
}
