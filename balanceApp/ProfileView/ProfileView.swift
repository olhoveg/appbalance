import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import MessageUI
import AppMetricaCore

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    // MARK: - Environment Object
    @EnvironmentObject var auth: AuthViewModel
    
    // MARK: - Состояния для Логина
    @State private var formattedPhone: String = ""
    @State private var smsCode: String = ""
    @State private var codeRequested: Bool = false
    @State private var remainingTime: Int = 0
    @State private var showRequestAgainButton: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    
    // MARK: - Состояния для Профиля
    @State private var clientName: String = "Имя пользователя"
    @State private var clientPhone: String = ""
    @State private var clientEmail: String = "email@example.com"
    @State private var showDeleteConfirmation = false
    @State private var profileImage: UIImage? = nil
    @State private var profileImageURL: URL? = nil
    @State private var isShowingImagePicker = false
    @State private var showFeedbackForm = false

    var body: some View {
        VStack {
            if auth.isLoggedIn {
                // ================================
                //     Профиль (если залогинен)
                // ================================
                ScrollView {
                    VStack(spacing: 20) {
                        // Аватар и имя
                        VStack(spacing: 12) {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            } else if let url = profileImageURL {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                } placeholder: {
                                    ProgressView().frame(width: 120, height: 120)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            }

                            Button("Изменить фото") {
                                isShowingImagePicker = true
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 8)

                            Text(clientName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 30)

                        // Контактная информация
                        VStack(spacing: 15) {
                            ProfileInfoRow(icon: "phone.fill", text: clientPhone)
                            ProfileInfoRow(icon: "envelope.fill", text: clientEmail)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Кнопки действий
                        VStack(spacing: 15) {
                            Button(action: {
                                auth.logout()
                            }) {
                                Text("Выйти из аккаунта")
                                    .fontWeight(.semibold)
                                    .foregroundColor(colorScheme == .dark ? .primary : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.black)
                                    .cornerRadius(10)
                            }

                            Button("Удалить аккаунт") {
                                showDeleteConfirmation = true
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)

                            Button("Написать разработчику") {
                                showFeedbackForm = true
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        Spacer()

                        // Версия приложения (при необходимости)
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Версия: \(version)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.bottom, 10)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationBarTitle("Профиль", displayMode: .inline)
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("Удаление аккаунта"),
                        message: Text("Вы уверены, что хотите удалить аккаунт? Это действие нельзя отменить."),
                        primaryButton: .destructive(Text("Удалить")) {
                            handleDeleteAccount()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(isPresented: $isShowingImagePicker) {
                    ImagePicker(selectedImage: $profileImage)
                }
                .sheet(isPresented: $showFeedbackForm) {
                    FeedbackFormView()
                }
                .onChange(of: profileImage) {
                    if profileImage != nil {
                        uploadPhoto()
                    }
                }
                .onAppear {
                    AppMetrica.reportEvent(name: "Пользователь открыл экран профиля")
                    // При появлении профиля берем данные из UserDefaults
                    clientPhone = UserDefaults.standard.string(forKey: "userPhone") ?? "Нет номера"
                    clientName = UserDefaults.standard.string(forKey: "userName") ?? "Имя пользователя"
                    clientEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "email@example.com"
                    
                    loadUserDataFromFirestore()
                    loadProfileImage()
                }

            } else {
                // ================================
                //   Логин (если НЕ залогинен)
                // ================================
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
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("Сообщение"),
                          message: Text(alertMessage),
                          dismissButton: .default(Text("OK"))
                    )
                }
                .onAppear {
                    // Проверяем статус авторизации при появлении
                    AppMetrica.reportEvent(name: "Пользователь открыл экран авторизации")
                    checkAuthStatus()
                }
            }
        }
    }
    
    // MARK: - Функции логина
    
    /// Проверяет, был ли пользователь авторизован ранее
    private func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            auth.loginSuccess()
        }
    }
    
    /// Обработка запроса кода
    private func handleRequestCode() {
        codeRequested = true
        remainingTime = 60
        requestSmsCode()
        startTimer()
    }
    
    /// Запуск таймера для повторного запроса
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
    
    /// Отправка запроса на получение кода
    private func requestSmsCode() {
        guard let url = URL(string: "https://api.yclients.com/api/v1/book_code/672239") else { return }
        
        let cleanedPhone = cleanPhoneNumber(formattedPhone)
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
                    alertMessage = "Код отправлен на \(cleanedPhone)"
                }
                showingAlert = true
            }
        }.resume()
    }
    
    /// При нажатии "Войти" отправляем код
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
                    alertMessage = "Ошибка при входе: \(error.localizedDescription)"
                    showingAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    alertMessage = "Неизвестная ошибка сети"
                    showingAlert = true
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    alertMessage = "Неверный код"
                    showingAlert = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let dataObj = json["data"] as? [String: Any] {
                        
                        // Извлекаем name и email из ответа
                        let userName = dataObj["name"] as? String ?? "Имя не указано"
                        let userEmail = dataObj["email"] as? String ?? "email@example.com"
                        
                        // Сохраняем в UserDefaults
                        UserDefaults.standard.set(cleanedPhone, forKey: "userPhone")
                        UserDefaults.standard.set(userName, forKey: "userName")
                        UserDefaults.standard.set(userEmail, forKey: "userEmail")
                        
                        // Авторизация прошла успешно
                        AppMetrica.reportEvent(name: "Пользователь успешно авторизовался")
                        auth.loginSuccess()
                        
                        alertMessage = "Вход выполнен!"
                        showingAlert = true
                    } else {
                        alertMessage = "Ошибка парсинга ответа сервера"
                        showingAlert = true
                    }
                } catch {
                    alertMessage = "Ошибка при чтении данных: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }.resume()
    }
    
    /// Преобразование введённого номера к "чистому" формату (только цифры)
    private func cleanPhoneNumber(_ formatted: String) -> String {
        formatted.filter { "0123456789".contains($0) }
    }
    
    // MARK: - Функции профиля
    
    private func handleDeleteAccount() {
        clearUserData()
        auth.logout()
    }
    
    private func clearUserData() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")

        // Если где-то есть кэш данных, можно очистить
        Task { @MainActor in
            RecordViewModel.sharedInstance.clearCachedRecords()
        }
    }
    
    private func loadUserDataFromFirestore() {
        let db = Firestore.firestore()
        db.collection("users").document(clientPhone).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                if let name = data["name"] as? String {
                    self.clientName = name
                    UserDefaults.standard.set(name, forKey: "userName")
                }
                if let email = data["email"] as? String {
                    self.clientEmail = email
                    UserDefaults.standard.set(email, forKey: "userEmail")
                }
            }
        }
    }
    
    private func loadProfileImage() {
        let db = Firestore.firestore()
        db.collection("users").document(clientPhone).getDocument { document, error in
            if let document = document, document.exists,
               let urlString = document.get("profileImageURL") as? String,
               let url = URL(string: urlString) {
                profileImageURL = url
            }
        }
    }
    
    private func uploadPhoto() {
        guard let image = profileImage,
              let imageData = image.jpegData(compressionQuality: 0.8),
              !clientPhone.isEmpty else { return }

        let storageRef = Storage.storage().reference().child("users/\(clientPhone)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("Ошибка загрузки фото: \(error.localizedDescription)")
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    savePhotoURL(url)
                }
            }
        }
    }
    
    private func savePhotoURL(_ url: URL) {
        let db = Firestore.firestore()
        db.collection("users").document(clientPhone).setData(
            ["profileImageURL": url.absoluteString],
            merge: true
        ) { error in
            if let error = error {
                print("Ошибка сохранения URL фото: \(error.localizedDescription)")
            } else {
                profileImageURL = url
            }
        }
    }
}

// MARK: - Дополнительные компоненты

/// Текстовое поле для ввода телефона с форматированием
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

            // Ограничение на 11 цифр (формат +7XXXXXXXXXX)
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

/// Строка отображения иконки и текста в профиле
struct ProfileInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal)
    }
}

/// Компонент для выбора изображения
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Превью (для наглядности)
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}

// MARK: - Форма обратной связи
import SwiftUI

struct FeedbackFormView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @AppStorage("userPhone") private var userPhone: String = ""
    
    @State private var isSending = false
    @State private var sendResult: String? = nil
    @State private var attachedImage: UIImage? = nil
    @State private var showImagePicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ваше имя")) {
                    TextField("Введите имя", text: $name)
                }
                
                Section(header: Text("Email")) {
                    TextField("Введите email", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text("Сообщение")) {
                    TextEditor(text: $message)
                        .frame(height: 150)
                }
                
                Section {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text(attachedImage == nil ? "Прикрепить фото" : "Фото прикреплено")
                            .foregroundColor(.blue)
                    }
                }
                
                if isSending {
                    HStack {
                        Spacer()
                        ProgressView("Отправка...")
                        Spacer()
                    }
                }
                
                if let result = sendResult {
                    HStack {
                        Spacer()
                        Text(result)
                            .foregroundColor(result == "Успешно отправлено!" ? .green : .red)
                        Spacer()
                    }
                }

                Button("Отправить") {
                    sendFeedback()
                }
                .disabled(message.isEmpty || isSending)
            }
            .navigationTitle("Обратная связь")
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $attachedImage)
        }
    }
    
    private func sendFeedback() {
        isSending = true
        sendResult = nil
        
        TelegramSender.shared.sendMessage(name: name, email: email, phone: userPhone, message: message, photo: attachedImage) { success in
            DispatchQueue.main.async {
                isSending = false
                sendResult = success ? "Успешно отправлено!" : "Ошибка отправки"

                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

import Foundation

class TelegramSender {
    static let shared = TelegramSender()
    
    private let botToken = "7907354811:AAH4-8ZdjOksEuACnh51kNI2YyC824FeWxs"
    private let chatId = "-1002640550524"
    
    func sendMessage(name: String, email: String, phone: String, message: String, photo: UIImage? = nil, completion: @escaping (Bool) -> Void) {
        let text = """
        📩 Новое сообщение от пользователя

        Имя: \(name)
        Телефон: \(phone)
        Email: \(email)
        Сообщение: \(message)
        """
        if let photo = photo,
           let imageData = photo.jpegData(compressionQuality: 0.7) {
            // Send photo with caption using multipart/form-data
            let urlString = "https://api.telegram.org/bot\(botToken)/sendPhoto"
            guard let url = URL(string: urlString) else {
                completion(false)
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            // chat_id
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n")
            body.append("\(chatId)\r\n")
            // caption
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
            body.append("\(text)\r\n")
            // photo
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"feedback.jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
            body.append("--\(boundary)--\r\n")
            request.httpBody = body
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка отправки фото: \(error)")
                    completion(false)
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        } else {
            // Send text-only message
            let urlString = "https://api.telegram.org/bot\(botToken)/sendMessage"
            guard let url = URL(string: urlString) else {
                completion(false)
                return
            }
            let parameters = [
                "chat_id": chatId,
                "text": text
            ]
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = parameters
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка отправки: \(error)")
                    completion(false)
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
