import SwiftUI

struct LoginScreen: View {
    @State private var username: String = ""
    @State private var formattedPhone: String = ""
    @State private var smsCode: String = ""
    @State private var codeRequested: Bool = false
    @State private var remainingTime: Int = 0
    @State private var showRequestAgainButton: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    @State private var shouldNavigate: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Поле ввода телефона
                TextField("+7 (___) ___ __ __", text: $formattedPhone)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(white: 0.9))
                    .cornerRadius(8)
                    .onChange(of: formattedPhone) { newValue in
                        handleFormattedPhoneChange(newValue)
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
                      dismissButton: .default(Text("OK"), action: {
                    if alertMessage == "Вход выполнен!" {
                        shouldNavigate = true
                    }
                }))
            }
            .onAppear {
                checkAuthStatus()
            }
        }
        // После успешной авторизации переходим на ContentView (главное меню с TabView)
        .fullScreenCover(isPresented: $shouldNavigate) {
            ContentView()
        }
    }
    
    // Проверка авторизации (например, через UserDefaults)
    private func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            shouldNavigate = true
        }
    }
    
    // Обработка ввода телефона
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
    
    // Форматирование номера телефона
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
    
    // Запрос SMS-кода
    private func handleRequestCode() {
        codeRequested = true
        remainingTime = 60
        requestSmsCode()
        startTimer()
    }
    
    // Таймер для повторного запроса кода
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
    
    // Отправка запроса на получение SMS-кода
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
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Ошибка отправки кода: \(error.localizedDescription)"
                } else {
                    alertMessage = "Код отправлен на \(username)"
                }
                showingAlert = true
            }
        }.resume()
    }
    
    // Отправка SMS-кода для авторизации и получение данных пользователя (name, email)
    private func handleSmsCodeSubmit() {
        guard let url = URL(string: "https://api.yclients.com/api/v1/user/auth") else {
            print("Неверный URL")
            return
        }
        let dataDict: [String: Any] = ["phone": username, "code": smsCode]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict) else {
            print("Ошибка сериализации JSON")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        print("Отправка запроса на авторизацию с данными: \(dataDict)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка сети: \(error.localizedDescription)")
                    alertMessage = "Ошибка при входе: \(error.localizedDescription)"
                    showingAlert = true
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Получен ответ с кодом статуса: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Ответ сервера: \(responseString)")
                    }
                    // Изменили условие проверки: считаем успешным любой статус от 200 до 299
                    if (200...299).contains(httpResponse.statusCode), let data = data {
                        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            print("JSON-ответ: \(jsonResponse)")
                            if let dataObject = jsonResponse["data"] as? [String: Any] {
                                let name = dataObject["name"] as? String ?? "Имя пользователя"
                                let email = dataObject["email"] as? String ?? "email@example.com"
                                // Сохраняем данные пользователя
                                UserDefaults.standard.set(name, forKey: "userName")
                                UserDefaults.standard.set(email, forKey: "userEmail")
                            }
                            alertMessage = "Вход выполнен!"
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            UserDefaults.standard.set(username, forKey: "userPhone")
                            showingAlert = true
                            shouldNavigate = true
                        } else {
                            print("Не удалось разобрать JSON-ответ")
                            alertMessage = "Ошибка разбора ответа сервера"
                            showingAlert = true
                        }
                    } else {
                        print("Неверный код, статус ответа: \(httpResponse.statusCode)")
                        alertMessage = "Неверный код"
                        showingAlert = true
                    }
                }
            }
        }.resume()
    }


    
    struct LoginScreen_Previews: PreviewProvider {
        static var previews: some View {
            LoginScreen()
        }
    }
}
