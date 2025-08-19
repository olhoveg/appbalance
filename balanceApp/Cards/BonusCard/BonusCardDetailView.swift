import SwiftUI

struct BonusCardDetailView: View {
    let bonusCard: BonusCard
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    
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
                        
                        // Дополнительная информация
                        if let points = bonusCard.points {
                            HStack {
                                Text("Бонусные баллы:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(points)")
                                    .fontWeight(.semibold)
                            }
                        }
                        
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
                    
                    // История транзакций
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("История операций")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            
                            if let transactions = bonusCard.transactions {
                                Text("\(transactions.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let transactions = bonusCard.transactions, !transactions.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(transactions.sorted(by: { $0.date > $1.date })) { transaction in
                                    TransactionRow(transaction: transaction)
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
                    
                    // Программы лояльности
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Программы лояльности")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            
                            if let programs = bonusCard.programs {
                                Text("\(programs.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let programs = bonusCard.programs, !programs.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(programs) { program in
                                    LoyaltyProgramCard(program: program)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("Нет активных программ лояльности")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Программы лояльности появятся здесь, когда будут доступны")
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
        }
    }
}

struct TransactionRow: View {
    let transaction: BonusCardTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка типа транзакции
            Image(systemName: transaction.isCredit ? "plus.circle.fill" : "minus.circle.fill")
                .font(.title2)
                .foregroundColor(transaction.isCredit ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = transaction.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let serviceName = transaction.serviceName {
                    Text(serviceName)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(formatDate(transaction.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
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
        transactions: [
            BonusCardTransaction(
                type: "Начисление",
                amount: 500.0,
                date: Date(),
                description: "Начисление за покупку услуги",
                serviceName: "Массаж спины"
            ),
            BonusCardTransaction(
                type: "Списание",
                amount: 200.0,
                date: Date().addingTimeInterval(-86400),
                description: "Оплата услуги бонусами",
                serviceName: "Маникюр"
            ),
            BonusCardTransaction(
                type: "Начисление",
                amount: 300.0,
                date: Date().addingTimeInterval(-172800),
                description: "Бонус за визит",
                serviceName: nil
            )
        ],
        programs: nil
    ))
}
