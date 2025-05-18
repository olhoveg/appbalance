//
//  CardsTabView.swift
//  balanceApp
//
//  Created by Evgen on 16.02.2025.
//

import SwiftUI
import AppMetricaCore

struct CardsTabView: View {
    @State private var selectedTab = 0 // Устанавливаем 0 для "Абонементы" (он будет первым)

    
    var body: some View {
        VStack {
            Picker("Выбор", selection: $selectedTab) {
                Text("Абонементы").tag(0)
                Text("Сертификаты").tag(1)
                Text("Бонусная карта").tag(2) // Добавляем новую вкладку
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedTab) { oldValue, value in
                switch value {
                case 0:
                    AppMetrica.reportEvent(name: "Пользователь выбрал 'Абонементы'")
                case 1:
                    AppMetrica.reportEvent(name: "Пользователь выбрал 'Сертификаты'")
                case 2:
                    AppMetrica.reportEvent(name: "Пользователь выбрал 'Бонусная карта'")
                default:
                    break
                }
            }

            // Отображение соответствующего контента в зависимости от выбранной вкладки
            switch selectedTab {
            case 0:
                SubscriptionsView() // Абонементы
            case 1:
                CertificatesView() // Сертификаты
            case 2:
                BonusBlockView() // Бонусная карта (нужно создать этот экран)
            default:
                Text("Ошибка: неизвестная вкладка") // На случай ошибки
            }
        }
    }
}

// Превью для SwiftUI
struct CardsTabView_Previews: PreviewProvider {
    static var previews: some View {
        CardsTabView()
    }
}

// Заглушка для нового экрана "Бонусная карта"
struct BonusCardView: View {
    var body: some View {
        VStack {
            Text("Бонусная карта")
                .font(.title)
                .bold()
                .padding()
            Text("Здесь будет информация о вашей бонусной карте")
                .foregroundColor(.gray)
                .padding()
        }
    }
}
