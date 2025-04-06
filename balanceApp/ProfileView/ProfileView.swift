import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct ProfileView: View {
    @State private var isLoggedIn: Bool = false
    @State private var clientName: String = "Имя пользователя"
    @State private var clientPhone: String = ""
    @State private var clientEmail: String = "email@example.com"
    @State private var showDeleteConfirmation = false
    @State private var shouldNavigateToMain = false

    // Переменные для работы с фотографией профиля
    @State private var profileImage: UIImage? = nil
    @State private var profileImageURL: URL? = nil
    @State private var isShowingImagePicker = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoggedIn {
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            // Аватар и имя пользователя
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
                                        ProgressView()
                                            .frame(width: 120, height: 120)
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
                                
                                // Кнопка для выбора/смены фото
                                Button(action: {
                                    isShowingImagePicker = true
                                }) {
                                    Text("Изменить фото")
                                        .foregroundColor(.blue)
                                }
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
                                Button(action: handleLogout) {
                                    Text("Выйти из аккаунта")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showDeleteConfirmation = true
                                }) {
                                    Text("Удалить аккаунт")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.black)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            // Отображение версии приложения в самом низу
                                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                            Text("Версия: \(version)")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                                .padding(.bottom, 10)
                                        }
                                    }
                                    .padding(.vertical)
                                }
                            } else {
                    // Если не авторизован – кнопка входа
                    NavigationLink(destination: LoginScreen()) {
                        Text("Войти")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkAuthStatus()
                if isLoggedIn {
                    // 1. Достаем из UserDefaults
                    clientPhone = UserDefaults.standard.string(forKey: "userPhone") ?? "Нет номера"
                    clientName  = UserDefaults.standard.string(forKey: "userName")  ?? "Имя пользователя"
                    clientEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "email@example.com"
                    
                    // 2. Если у вас есть Firestore – подгружаем из него (если надо)
                    loadUserDataFromFirestore()
                    loadProfileImage()
                }
            }
            .fullScreenCover(isPresented: $shouldNavigateToMain) {
                ContentView()
            }
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
            // Открытие ImagePicker для выбора фото
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: $profileImage)
            }
            // При выборе нового изображения выполняем его загрузку
            .onChange(of: profileImage) { newImage, _ in
                if newImage != nil {
                    uploadPhoto()
                }
            }
        }
    }
    
    // Чтение данных из UserDefaults
    private func checkAuthStatus() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            clientPhone = UserDefaults.standard.string(forKey: "userPhone") ?? "Нет номера"
            clientName  = UserDefaults.standard.string(forKey: "userName")  ?? "Имя пользователя"
            clientEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "email@example.com"
            print("UserDefaults - userPhone: \(clientPhone), userName: \(clientName), userEmail: \(clientEmail)")
        }
    }
    
    // Загрузка данных из Firestore с логированием всего документа
    private func loadUserDataFromFirestore() {
        let db = Firestore.firestore()
        db.collection("users").document(clientPhone).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                print("Firestore document data: \(data)")
                if let name = data["name"] as? String {
                    self.clientName = name
                    UserDefaults.standard.set(name, forKey: "userName")
                } else {
                    print("Поле 'name' отсутствует. Доступные поля: \(data.keys)")
                }
                if let email = data["email"] as? String {
                    self.clientEmail = email
                    UserDefaults.standard.set(email, forKey: "userEmail")
                } else {
                    print("Поле 'email' отсутствует. Доступные поля: \(data.keys)")
                }
            } else {
                print("Документ не найден или произошла ошибка: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }
    
    // Функции работы с фото (uploadPhoto, savePhotoURL, loadProfileImage)
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
        db.collection("users").document(clientPhone).setData(["profileImageURL": url.absoluteString], merge: true) { error in
            if let error = error {
                print("Ошибка сохранения URL фото: \(error.localizedDescription)")
            } else {
                print("URL фото успешно сохранён")
                profileImageURL = url
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
    
    // Функции выхода/удаления аккаунта
    private func handleLogout() {
        clearUserData()
        shouldNavigateToMain = true
    }
    
    private func handleDeleteAccount() {
        clearUserData()
        shouldNavigateToMain = true
    }
    
    private func clearUserData() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        // Очищаем кэш расписания
        RecordViewModel.sharedInstance.clearCachedRecords()
        isLoggedIn = false
    }
}

// Компонент строки профиля (иконка + текст)
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

// Компонент для выбора изображения из библиотеки
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
       
       func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
           if let editedImage = info[.editedImage] as? UIImage {
               parent.selectedImage = editedImage
           } else if let originalImage = info[.originalImage] as? UIImage {
               parent.selectedImage = originalImage
           }
           parent.presentationMode.wrappedValue.dismiss()
       }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
