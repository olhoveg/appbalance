import SwiftUI

struct BonusCardDetailView: View {
    let bonusCard: BonusCard
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var selectedFilter: TransactionFilter = .last10
    @State private var customDateRange: DateRange = DateRange(start: Date().addingTimeInterval(-30*24*60*60), end: Date())
    @State private var showingDatePicker = false
    @State private var loyaltyPrograms: [LoyaltyProgram] = []
    @State private var isLoadingPrograms = false
    
    enum TransactionFilter: String, CaseIterable {
        case last10 = "Последние 10"
        case last30 = "Последние 30"
        case last90 = "Последние 90"
        case custom = "Выбрать период"
        
        var count: Int? {
            switch self {
            case .last10: return 10
            case .last30: return 30
            case .last90: return 90
            case .custom: return nil
            }
        }
    }
    
    struct DateRange {
        var start: Date
        var end: Date
    }
    
    var filteredTransactions: [AppTransaction] {
        guard let transactions = bonusCard.transactions else { return [] }
        
        let sortedTransactions = transactions.sorted(by: { $0.date > $1.date })
        
        switch selectedFilter {
        case .last10, .last30, .last90:
            guard let count = selectedFilter.count else { return sortedTransactions }
            return Array(sortedTransactions.prefix(count))
        case .custom:
            return sortedTransactions.filter { transaction in
                transaction.date >= customDateRange.start && transaction.date <= customDateRange.end
            }
        }
    }
    
    private func fetchLoyaltyPrograms() {
        guard !isLoadingPrograms else { return }
        
        isLoadingPrograms = true
        
        // Сначала проверяем, есть ли программы уже в bonusCard
        if let existingPrograms = bonusCard.programs, !existingPrograms.isEmpty {
            print("✅ Используем программы из bonusCard: \(existingPrograms.count)")
            self.loyaltyPrograms = existingPrograms
            self.isLoadingPrograms = false
            return
        }
        
        let companyId = "433675"
        let urlString = "https://api.yclients.com/api/v1/loyalty/programs/\(companyId)"
        
        print("🔄 Загружаем программы лояльности: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            isLoadingPrograms = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingPrograms = false
                
                if let error = error {
                    print("❌ Ошибка загрузки программ лояльности: \(error)")
                    return
                }
                
                guard let data = data else { 
                    print("❌ Нет данных в ответе программ лояльности")
                    return 
                }
                
                // Выводим сырой ответ для отладки
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Сырой ответ API программ лояльности: \(jsonString)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(LoyaltyProgramsResponse.self, from: data)
                    self.loyaltyPrograms = response.data
                    print("✅ Загружено программ лояльности: \(self.loyaltyPrograms.count)")
                } catch {
                    print("❌ Ошибка декодирования программ лояльности: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 JSON для отладки: \(jsonString)")
                    }
                    
                    // Попробуем альтернативный формат
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode([LoyaltyProgram].self, from: data)
                        self.loyaltyPrograms = response
                        print("✅ Загружено программ лояльности (альтернативный формат): \(self.loyaltyPrograms.count)")
                    } catch {
                        print("❌ Ошибка декодирования программ лояльности (альтернативный формат): \(error)")
                    }
                }
            }
        }.resume()
    }
    
    private func getLoyaltyProgramName(for programId: Int?) -> String? {
        guard let programId = programId else { return nil }
        
        print("🔍 Ищем программу с ID: \(programId)")
        print("📋 Количество доступных программ: \(loyaltyPrograms.count)")
        
        let program = loyaltyPrograms.first { $0.id == programId }
        
        if let program = program {
            print("✅ Найдена программа: \(program.title)")
            return program.title
        } else {
            print("❌ Программа с ID \(programId) не найдена")
            return "Программа #\(programId)"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Карточка с балансом
                    VStack(spacing: 16) {
                        // Номер карты
                        HStack {
                            Text("№ \(bonusCard.number)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Баланс
                        VStack(spacing: 8) {
                            Text("Текущий баланс")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", bonusCard.balance)) ₽")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        // Дополнительная информация (убрали бонусные баллы)
                        if let visitsCount = bonusCard.visitsCount {
                            HStack {
                                Text("Количество визитов:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(visitsCount)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // История транзакций с фильтром
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("История операций")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            
                            Text("\(filteredTransactions.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Фильтр транзакций
                        VStack(spacing: 12) {
                            HStack {
                                Text("Фильтр:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                                        Button(action: {
                                            selectedFilter = filter
                                            if filter == .custom {
                                                showingDatePicker = true
                                            }
                                        }) {
                                            Text(filter.rawValue)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                        
                        if !filteredTransactions.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTransactions) { transaction in
                                    let programName = getLoyaltyProgramName(for: transaction.programId)
                                    TransactionRow(
                                        transaction: transaction,
                                        loyaltyProgramName: programName
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("История операций пока недоступна")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Транзакции появятся здесь после совершения операций")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Бонусная карта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Здесь можно добавить обновление данных
                        print("Обновление данных бонусной карты")
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("🎯 BonusCardDetailView appeared")
                let programsCount = bonusCard.programs?.count ?? 0
                print("📋 BonusCard programs count: \(programsCount)")
                fetchLoyaltyPrograms()
            }
            .sheet(isPresented: $showingDatePicker) {
                DateRangePickerView(dateRange: $customDateRange, isPresented: $showingDatePicker)
            }
        }
    }
}

struct DateRangePickerView: View {
    @Binding var dateRange: BonusCardDetailView.DateRange
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите период")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Начальная дата")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $dateRange.start, in: ...dateRange.end, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Конечная дата")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $dateRange.end, in: dateRange.start...Date(), displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Выбор периода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Применить") {
                        // Проверяем, что начальная дата не позже конечной
                        if dateRange.start > dateRange.end {
                            dateRange.start = dateRange.end
                        }
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: AppTransaction
    let loyaltyProgramName: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка типа транзакции
            Image(systemName: transaction.isCredit ? "plus.circle.fill" : "minus.circle.fill")
                .font(.title2)
                .foregroundColor(transaction.isCredit ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                // Если есть программа лояльности, показываем её название вместо типа транзакции
                if let programName = loyaltyProgramName {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(programName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text(transaction.type.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDate(transaction.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Показываем тип транзакции как дополнительную информацию
                    if loyaltyProgramName != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(transaction.type.title)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isCredit ? .green : .red)
            }
        }
        .padding()
        .background(
            loyaltyProgramName != nil 
                ? Color.orange.opacity(0.1) 
                : Color(UIColor.secondarySystemBackground)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    loyaltyProgramName != nil 
                        ? Color.orange.opacity(0.3) 
                        : Color.clear, 
                    lineWidth: 1
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

// Структура для ответа API программ лояльности
struct LoyaltyProgramsResponse: Codable {
    let success: Bool
    let data: [LoyaltyProgram]
}

#Preview {
    BonusCardDetailView(bonusCard: BonusCard(
        id: 1,
        number: "1234567890",
        balance: 1500.50,
        points: 150,
        paidAmount: 5000,
        soldAmount: 3500,
        visitsCount: 5,
        typeId: 1,
        salonGroupId: 1,
        maxDiscountPercent: 10,
        maxDiscountAmount: 500,
        type: BonusCardType(
            id: 1,
            title: "Стандартная",
            salonGroupId: 1,
            serviceItemType: "service",
            goodItemType: "good"
        ),
        transactions: [],
        programs: nil
    ))
}
