//
//  AuthViewModel.swift
//  balanceApp
//
//  Created by Olkhov on 08.04.2025.
//

import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @Published var phone: String = UserDefaults.standard.string(forKey: "userPhone") ?? ""
    
    func loginSuccessfully(with phone: String) {
        self.phone = phone
        isLoggedIn = true
        UserDefaults.standard.set(phone, forKey: "userPhone")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
    }
    
    func logout() {
        isLoggedIn = false
        phone = ""
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
    }


    
    func loginSuccessfully() {
        isLoggedIn = true
    }
}
