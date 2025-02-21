//
//  MainView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 20.02.2025.
//

import SwiftUI
import OneSignalFramework

struct MainView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Наш кастомный NavigationBar наверху
                CustomNavigationBar()
                
                // Основной контент ниже
                ScrollView {
                    VStack(spacing: 20) {
                        StoriesView()
                        RecordView()
                        
                        Divider()
                        
                        RecommendationsView()
                        
                        Divider()
                        
                        ArticlesView()
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Инициализируем OneSignal один раз
            OneSignalManager.shared.initializeOneSignal()
        }
    }
}

// MARK: - OneSignalManager (синглтон)
class OneSignalManager: NSObject, OSPushSubscriptionObserver {
    static let shared = OneSignalManager()
    private var isInitialized = false
    private override init() {}
    
    func initializeOneSignal() {
        guard !isInitialized else {
            print("OneSignal уже инициализирован")
            return
        }
        isInitialized = true
        
        // Устанавливаем уровень логирования OneSignal
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        
        // Инициализируем OneSignal с вашим App ID
        OneSignal.initialize("61e511f4-5929-448d-85f4-e5bf171f0764", withLaunchOptions: nil)
        
        // Запрос разрешения на уведомления
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: true)
        
        // Подписываемся на изменения pushSubscription
        OneSignal.User.pushSubscription.addObserver(self)
        
        // Получаем текущий playerId (если доступен)
        if let playerId = OneSignal.User.pushSubscription.id {
            self.savePlayerId(playerId)
        }
        
        print("OneSignal успешно инициализирован")
    }
    
    // MARK: - OSPushSubscriptionObserver
    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        if let playerId = state.current.id {
            self.savePlayerId(playerId)
        }
    }
    
    private func savePlayerId(_ playerId: String) {
        UserDefaults.standard.set(playerId, forKey: "OneSignalPlayerID")
        print("PlayerID сохранен: \(playerId)")
    }
    
    func getPlayerId() -> String? {
        return UserDefaults.standard.string(forKey: "OneSignalPlayerID")
    }
}

// MARK: - Кастомный NavigationBar
struct CustomNavigationBar: View {
    var body: some View {
        HStack {
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.black)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(1)
            
            Spacer()
            
            Text("Главная")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    if let url = URL(string: "https://wa.me/79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "message.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if let url = URL(string: "tel://+79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}



// MARK: - Пример блока рекомендаций
struct RecommendationsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Рекомендации")
                .font(.headline)
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        NavigationLink(destination: RecommendationDetailView(id: index)) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green)
                                .frame(width: 150, height: 100)
                                .overlay(Text("Рекомендация \(index + 1)").foregroundColor(.white))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Пример блока статей
struct ArticlesView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Статьи")
                .font(.headline)
                .padding(.leading)
            List(0..<5, id: \.self) { index in
                NavigationLink(destination: ArticleDetailView(id: index)) {
                    Text("Статья \(index + 1)")
                }
            }
            .frame(height: 250)
        }
    }
}

// MARK: - Детальные страницы
struct RecommendationDetailView: View {
    var id: Int
    var body: some View {
        Text("Детальная страница рекомендации \(id + 1)")
            .font(.largeTitle)
    }
}

struct ArticleDetailView: View {
    var id: Int
    var body: some View {
        Text("Детальная страница статьи \(id + 1)")
            .font(.largeTitle)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MainView()
        }
    }
}
