import SwiftUI

private let API_KEY = "88fnh8jbmt44er5y28nj"

struct AbonementDetailView: View {
    let abonement: Abonement
    @Environment(\.colorScheme) var colorScheme
    @State private var transactions: [AbonementTransaction] = []
    @State private var isLoading = true
    @State private var selectedTransaction: AppTransaction?
    
    private var userPhone: String {
        UserDefaults.standard.string(forKey: "userPhone") ?? ""
    }

    var body: some View {
        List {
            Section(header: Text("Основная информация")) {
                InfoRow(icon: "number", title: "Номер", value: abonement.number)
                InfoRow(icon: "tag", title: "Тип", value: abonement.type.title)
                InfoRow(icon: "calendar", title: "Дата покупки", value: formattedDate(abonement.createdDate))
                if let expDate = abonement.expirationDate {
                    InfoRow(icon: "hourglass.bottomhalf.fill", title: "Срок окончания", value: formattedDate(expDate))
                } else {
                    InfoRow(icon: "infinity", title: "Срок окончания", value: "Бессрочный")
                }
            }

            Section(header: Text("История использования")) {
                if let transactions = abonement.transactions, !transactions.isEmpty {
                    let initialBalance = abonement.balance + transactions.count
                    ForEach(transactions.indices, id: \.self) { index in
                        let balanceBefore = initialBalance - index
                        UsageHistoryRow(transaction: transactions[index], balanceBefore: balanceBefore, balanceAfter: balanceBefore - 1)
                            .onTapGesture {
                                selectedTransaction = transactions[index]
                            }
                    }
                } else {
                    Text("История использования пуста.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Детали абонемента")
        .sheet(item: $selectedTransaction) { transaction in
            VStack(alignment: .leading, spacing: 20) {
                Text("Детали сеанса")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                if let visitDetails = transaction.visitDetails {
                    InfoRow(icon: "scissors", title: "Услуга", value: visitDetails.serviceTitle)
                    InfoRow(icon: "person", title: "Специалист", value: visitDetails.specialistName)
                    InfoRow(icon: "calendar", title: "Дата", value: formattedDate(visitDetails.startTime))
                    InfoRow(icon: "clock", title: "Начало", value: formatTime(visitDetails.startTime))
                    InfoRow(icon: "clock.fill", title: "Окончание", value: formatTime(visitDetails.endTime))
                    InfoRow(icon: "rublesign.circle", title: "Стоимость", value: "\(visitDetails.serviceCost) ₽")
                } else {
                    Text("Нет данных")
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            print("Abonement details: \(abonement)")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct UsageHistoryRow: View {
    let transaction: AppTransaction
    let balanceBefore: Int
    let balanceAfter: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Использование сеанса")
                    .font(.headline)
                Text(transaction.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Text("\(balanceBefore)")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(balanceAfter)")
                    .font(.headline)
            }
        }
    }
}

