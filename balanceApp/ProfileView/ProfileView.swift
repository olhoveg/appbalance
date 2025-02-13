//
//  ProfileView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 13.02.2025.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @State private var isLoggedIn: Bool = false
    @State private var clientName: String = ""
    @State private var clientPhone: String = ""
    @State private var clientEmail: String = ""

    var body: some View {
        NavigationView {
            VStack {
                if isLoggedIn {
                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.blue)
                            Text(clientName)
                                .font(.title2)
                                .bold()
                        }

                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                            Text(clientPhone)
                        }

                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text(clientEmail)
                        }

                        Button(action: handleLogout) {
                            Text("Выйти из аккаунта")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        
                        Button(action: showDeleteAccountAlert) {
                            Text("Удалить аккаунт")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else {
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
            .onAppear {
                checkAuthStatus()
            }
        }
    }

    // Проверка авторизации
    private func checkAuthStatus() {
        if let user = Auth.auth().currentUser {
            isLoggedIn = true
            clientPhone = user.phoneNumber ?? "Нет номера"
            fetchClientData(phone: clientPhone)
        } else {
            isLoggedIn = false
        }
    }

    // Получение данных пользователя из Firestore
    private func fetchClientData(phone: String) {
        let db = Firestore.firestore()
        db.collection("users").whereField("phone", isEqualTo: phone).getDocuments { snapshot, error in
            if let error = error {
                print("Ошибка загрузки данных: \(error.localizedDescription)")
                return
            }

            if let document = snapshot?.documents.first {
                self.clientName = document.data()["name"] as? String ?? "Без имени"
                self.clientEmail = document.data()["email"] as? String ?? "Нет email"
            }
        }
    }

    // Выход из аккаунта
    private func handleLogout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch let error {
            print("Ошибка при выходе: \(error.localizedDescription)")
        }
    }

    // Подтверждение удаления аккаунта
    private func showDeleteAccountAlert() {
        let alert = UIAlertController(title: "Удаление аккаунта", message: "Вы уверены, что хотите удалить аккаунт?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { _ in
            handleDeleteAccount()
        }))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }

    // Удаление аккаунта
    private func handleDeleteAccount() {
        guard let user = Auth.auth().currentUser else { return }

        user.delete { error in
            if let error = error {
                print("Ошибка удаления аккаунта: \(error.localizedDescription)")
            } else {
                print("Аккаунт удален")
                isLoggedIn = false
            }
        }
    }
}
