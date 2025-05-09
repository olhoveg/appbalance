//
//  AuthView.swift
//  balanceApp
//
//  Created by Olkhov on 10.04.2025.
//

import SwiftUI
import Foundation

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false

    init() {
        // например, при старте проверяем UserDefaults
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
    }

    func loginSuccess() {
        isLoggedIn = true
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
    }

    func logout() {
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userPhone") // 🔑 Вот это важно!

        // Отменяем все запланированные push‑уведомления и очищаем локальный кэш записей
        Task { @MainActor in
            RecordViewModel.shared.clearCachedRecords()
        }
    }
}
