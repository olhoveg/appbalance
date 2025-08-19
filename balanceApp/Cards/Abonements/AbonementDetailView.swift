import SwiftUI

struct AbonementDetailView: View {
    let abonement: Abonement
    @Environment(\.colorScheme) var colorScheme

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

            Section(header: Text("История списаний")) {
                Text("История списаний пуста.")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Детали абонемента")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

