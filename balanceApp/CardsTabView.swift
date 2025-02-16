//
//  CardsTabView.swift
//  balanceApp
//
//  Created by Evgen on 16.02.2025.
//

import SwiftUI

struct CardsTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Выбор", selection: $selectedTab) {
                Text("Сертификаты").tag(0)
                Text("Абонементы").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                CertificatesView()
            } else {
                SubscriptionsView()
            }
        }
    }
}

struct CardsTabView_Previews: PreviewProvider {
    static var previews: some View {
        CardsTabView()
    }
}
