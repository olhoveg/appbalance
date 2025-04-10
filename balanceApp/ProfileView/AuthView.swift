//
//  Untitled.swift
//  balanceApp
//
//  Created by Olkhov on 10.04.2025.
//
import SwiftUI

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
    }
}
