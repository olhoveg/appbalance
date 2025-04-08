//
//  RootView.swift
//  balanceApp
//
//  Created by Olkhov on 08.04.2025.
//

import SwiftUI

struct RootView: View {
    @State private var isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")

    var body: some View {
        Group {
            if isLoggedIn {
                ContentView()
            } else {
                LoginScreen(onSuccess: {
                    // После успешного логина:
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    RecordViewModel.sharedInstance.getPhoneNumber()
                    isLoggedIn = true
                })
            }
        }
        .onAppear {
            // Перезагружаем статус на случай выхода
            isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        }
    }
}
