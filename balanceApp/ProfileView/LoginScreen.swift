////LoginScreen.swift


import SwiftUI
import FirebaseDatabase
import Firebase

struct PhoneNumberField: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textAlignment = .center
        textField.attributedPlaceholder = NSAttributedString(
            string: "+7 (XXX) XXX XX XX",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PhoneNumberField

        init(_ parent: PhoneNumberField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            let newText = textField.text ?? ""
            let formatted = formatPhoneNumber(newText)
            parent.text = formatted
        }

        private func formatPhoneNumber(_ number: String) -> String {
            var digits = number.filter { "0123456789".contains($0) }

            // Автоматически заменяем 8 или 9 в начале на +7
            if digits.hasPrefix("89") {
                digits.removeFirst()
            }
            if digits.hasPrefix("9") {
                digits = "7" + digits
            }

            // Ограничение на 10 цифр (без учета +7)
            if digits.count > 11 {
                digits = String(digits.prefix(11))
            }

            var formatted = "+7 "

            if digits.count > 1 {
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
            }
            return formatted.trimmingCharacters(in: .whitespaces)
        }
    }
}


struct LoginScreen: View {
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
                Text("Введите номер телефона")
                    .font(.headline)
                
                PhoneNumberField(text: $formattedPhone)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .foregroundColor(Color(.label))
                    .frame(height: 50)
                
                TextField("Введите код", text: $smsCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .foregroundColor(Color(.label))
                
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
                .disabled(formattedPhone.count < 18 || smsCode.count != 4)
                
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
                .disabled(formattedPhone.count < 18)
                
                if codeRequested {
                    Text("Повторно запросить код можно через \(remainingTime) секунд")
                        .foregroundColor(.gray)
                }
                
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
        .fullScreenCover(isPresented: $shouldNavigate) {
            ContentView()
        }
    }
    
    private func cleanPhoneNumber(_ formatted: String) -> String {
        return formatted
            .filter { "0123456789".contains($0) } // Оставляем только цифры
    }
    
    
    private func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            shouldNavigate = true
        }
    }
    
    private func handleRequestCode() {
        codeRequested = true
        remainingTime = 60
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
        
        let cleanedPhone = cleanPhoneNumber(formattedPhone) // Очистка номера перед отправкой
        let dataDict: [String: Any] = ["phone": cleanedPhone]
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
                    alertMessage = "Код отправлен на \(cleanedPhone)" // Показываем правильный номер
                }
                showingAlert = true
            }
        }.resume()
    }
    
    
    private func handleSmsCodeSubmit() {
        guard let url = URL(string: "https://api.yclients.com/api/v1/user/auth") else { return }
        
        let cleanedPhone = cleanPhoneNumber(formattedPhone)
        let dataDict: [String: Any] = ["phone": cleanedPhone, "code": smsCode]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.yclients.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Ошибка при входе: \(error.localizedDescription)"
                    self.showingAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.alertMessage = "Неизвестная ошибка сети"
                    self.showingAlert = true
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    self.alertMessage = "Неверный код"
                    self.showingAlert = true
                    return
                }

                do {
                    // Пробуем распарсить JSON
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let dataObj = json["data"] as? [String: Any] {
                        
                        // Извлекаем name и email (если они приходят в ответе YClients)
                        let userName = dataObj["name"] as? String ?? "Имя не указано"
                        let userEmail = dataObj["email"] as? String ?? "email@example.com"
                        
                        // Сохраняем в UserDefaults
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(cleanedPhone, forKey: "userPhone")
                        UserDefaults.standard.set(userName, forKey: "userName")
                        UserDefaults.standard.set(userEmail, forKey: "userEmail")
                        
                        // Если нужно — параллельно сохраняем в Firestore
                        // let db = Firestore.firestore()
                        // db.collection("users").document(cleanedPhone).setData([
                        //     "name": userName,
                        //     "email": userEmail
                        // ], merge: true)
                        
                        self.alertMessage = "Вход выполнен!"
                        self.showingAlert = true
                        self.shouldNavigate = true
                    } else {
                        self.alertMessage = "Ошибка парсинга ответа сервера"
                        self.showingAlert = true
                    }
                } catch {
                    self.alertMessage = "Ошибка при чтении данных: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }.resume()
    }

}
    struct LoginScreen_Previews: PreviewProvider {
        static var previews: some View {
            LoginScreen()
        }
    }

