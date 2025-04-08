import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel  // Единый источник состояния авторизации
    @Environment(\.presentationMode) var presentationMode
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
                ScrollView {
                    VStack(spacing: 20) {
                        // Блок с аватаром, именем, контактами и т.д.
                        VStack(spacing: 12) {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            } else if let url = profileImageURL {
                                VStack {
                                    // Не выводим URL пользователю в продакшене
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 120, height: 120)
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                        case .failure:
                                            VStack {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 120, height: 120)
                                                    .foregroundColor(.blue)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                            }
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
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
                            Button(action: {
                                handleLogout()
                            }) {
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
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Версия: \(version)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.bottom, 10)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                clientPhone = UserDefaults.standard.string(forKey: "userPhone") ?? "Нет номера"
                clientName  = UserDefaults.standard.string(forKey: "userName")  ?? "Имя пользователя"
                clientEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "email@example.com"
                loadUserDataFromFirestore()
                loadProfileImage()
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Удаление аккаунта"),
                    message: Text("Вы уверены, что хотите удалить аккаунт? Это действие нельзя отменить."),
                    primaryButton: .destructive(Text("Удалить")) {
                        authVM.logout()
                        shouldNavigateToMain = true
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: $profileImage)
            }
            .onChange(of: profileImage) { newImage, _ in
                if newImage != nil {
                    uploadPhoto()
                }
            }
        }
    }
    
    private func handleLogout() {
        authVM.logout()
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: - Методы загрузки данных из Firestore
    private func loadUserDataFromFirestore() {
        let db = Firestore.firestore()
        db.collection("users").document(self.clientPhone).getDocument { document, error in
            guard let document = document, document.exists, let data = document.data() else { return }
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
    
    // MARK: - Методы работы с фото
    private func uploadPhoto() {
        guard let image = self.profileImage,
              let imageData = image.jpegData(compressionQuality: 0.8),
              !self.clientPhone.isEmpty, self.clientPhone != "Нет номера" else { return }
        
        let storageRef = Storage.storage().reference().child("users/\(self.clientPhone)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { _, error in
            if error != nil { return }
            storageRef.downloadURL { url, error in
                if let url = url {
                    self.savePhotoURL(url)
                }
            }
        }
    }
    
    private func savePhotoURL(_ url: URL) {
        let db = Firestore.firestore()
        db.collection("users").document(self.clientPhone).setData(["profileImageURL": url.absoluteString], merge: true) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.profileImageURL = url
                }
            }
        }
    }
    
    private func loadProfileImage() {
        let db = Firestore.firestore()
        db.collection("users").document(self.clientPhone).getDocument { document, error in
            guard let document = document, document.exists,
                  let urlString = document.get("profileImageURL") as? String,
                  let url = URL(string: urlString) else { return }
            DispatchQueue.main.async {
                self.profileImageURL = url
            }
        }
    }
}

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
            .environmentObject(AuthViewModel())
    }
}
