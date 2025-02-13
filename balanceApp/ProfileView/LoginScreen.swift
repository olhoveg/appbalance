//
//  LoginScreen.swift
//  balanceApp
//
//  Created by YourName on 13.02.2025.
//

import SwiftUI

struct LoginScreen: View {
    // Поля для телефона и кода
    @State private var username: String = ""
    @State private var formattedPhone: String = ""
    @State private var smsCode: String = ""
    
    // Состояния для работы с таймером и запросами
    @State private var codeRequested: Bool = false
    @State private var remainingTime: Int = 0
    @State private var showRequestAgainButton: Bool = false
    
    // Для Alert
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    
    // Флаг для навигации на HomeView
    @State private var shouldNavigate: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Скрытый NavigationLink для перехода на HomeView
                NavigationLink(destination: HomeView(), isActive: $shouldNavigate) {
                    EmptyView()
                }
                
                // Поле ввода телефона
                TextField("+7 (___) ___ __ __", text: $formattedPhone)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(white: 0.9))
                    .cornerRadius(8)
                    .onChange(of: formattedPhone) { newValue in
                        handleFormattedPhoneChange(newValue)
                        print("Новый форматированный номер: \(formattedPhone)")
                    }
                
                // Поле ввода SMS-кода
                TextField("Введите код", text: $smsCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(white: 0.9))
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
                    .font(.title)
                
                // Кнопка "Войти"
                Button(action: {
                    handleSmsCodeSubmit()
                }) {
                    Text("Войти")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(username.isEmpty || smsCode.count != 4)
                
                // Кнопка "Запросить код"
                Button(action: {
                    handleRequestCode()
                }) {
                    Text("Запросить код")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(username.isEmpty)
                
                // Таймер, если код запрошен
                if codeRequested {
                    Text("Повторно запросить код можно через \(remainingTime) секунд")
                        .foregroundColor(.gray)
                }
                
                // Кнопка повторного запроса, если таймер истёк
                if showRequestAgainButton && remainingTime == 0 {
                    Button(action: {
                        handleRequestCode()
                        showRequestAgainButton = false
                    }) {
                        Text("Запросить код повторно")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .navigationTitle("Авторизация")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Сообщение"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .onAppear {
                checkAuthStatus()
            }
        }
    }
}

// MARK: - Логика работы

extension LoginScreen {
    
    private func handleFormattedPhoneChange(_ input: String) {
        let digits = input.filter { "0123456789".contains($0) }
        if digits.isEmpty {
            username = ""
            formattedPhone = ""
            return
        }
        var normalized = digits
        if !normalized.hasPrefix("7") {
            if normalized.first == "9" {
                normalized = "7" + normalized
            }
        }
        username = normalized
        formattedPhone = formatPhoneNumber(normalized)
    }
    
    private func formatPhoneNumber(_ digits: String) -> String {
        let prefix = "+7 "
        var formatted = prefix
        let remaining = String(digits.dropFirst())
        
        let areaCode   = remaining.prefix(3)
        let firstPart  = remaining.dropFirst(3).prefix(3)
        let secondPart = remaining.dropFirst(6).prefix(2)
        let thirdPart  = remaining.dropFirst(8).prefix(2)
        
        if !areaCode.isEmpty {
            formatted += "(\(areaCode)) "
        }
        if !firstPart.isEmpty {
            formatted += firstPart
        }
        if !secondPart.isEmpty {
            formatted += " " + secondPart
        }
        if !thirdPart.isEmpty {
            formatted += " " + thirdPart
        }
        return formatted.trimmingCharacters(in: .whitespaces)
    }
    
    private func handleRequestCode() {
        codeRequested = true
        remainingTime = 60
        // Если хотите, чтобы поле с SMS-кодом активировалось, можно добавить флаг, но здесь оставляем как есть
        requestSmsCode()
        startTimer()
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.codeRequested = false
                self.showRequestAgainButton = true
                timer.invalidate()
            }
        }
    }
    
    private func requestSmsCode() {
        guard let url = URL(string: "https://api.yclients.com/api/v1/book_code/672239") else { return }
        let dataDict: [String: Any] = ["phone": username]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Ошибка отправки кода: \(error.localizedDescription)"
                    showingAlert = true
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    alertMessage = "Код отправлен на \(username)"
                    showingAlert = true
                }
            } else {
                let responseData = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async {
                    alertMessage = "Ошибка отправки кода: \(responseData)"
                    showingAlert = true
                }
            }
        }.resume()
    }
    
    private func handleSmsCodeSubmit() {
        guard let url = URL(string: "https://api.yclients.com/api/v1/user/auth") else { return }
        let dataDict: [String: Any] = ["phone": username, "code": smsCode]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Ошибка при входе: \(error.localizedDescription)"
                    showingAlert = true
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    alertMessage = "Вход выполнен!"
                    showingAlert = true
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    UserDefaults.standard.set(self.username, forKey: "phone")
                    
                    // Переход на HomeView
                    shouldNavigate = true
                }
            } else {
                let responseData = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async {
                    alertMessage = "Ошибка входа: \(responseData)"
                    showingAlert = true
                }
            }
        }.resume()
    }
    
    private func checkAuthStatus() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            print("Пользователь уже авторизован")
            shouldNavigate = true
        } else {
            print("Пользователь не авторизован")
        }
    }
}
