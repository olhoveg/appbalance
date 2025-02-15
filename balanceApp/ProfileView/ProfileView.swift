import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @State private var isLoggedIn: Bool = false
    @State private var clientName: String = "Имя пользователя"
    @State private var clientPhone: String = ""
    @State private var clientEmail: String = "email@example.com"
    @State private var showDeleteConfirmation = false
    @State private var shouldNavigateToMain = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoggedIn {
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            // Аватар и имя пользователя
                            VStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                
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
                        }
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
        }
    }
    
    // Проверка авторизации и загрузка данных пользователя
    private func checkAuthStatus() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            clientPhone = UserDefaults.standard.string(forKey: "userPhone") ?? "Нет номера"
            clientName = UserDefaults.standard.string(forKey: "userName") ?? "Имя пользователя"
            clientEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "email@example.com"
        }
    }
    
    // Функция выхода из аккаунта
    private func handleLogout() {
        clearUserData()
        shouldNavigateToMain = true
    }
    
    // Функция удаления аккаунта (фиктивная)
    private func handleDeleteAccount() {
        clearUserData()
        shouldNavigateToMain = true
    }
    
    // Очистка данных пользователя
    private func clearUserData() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
