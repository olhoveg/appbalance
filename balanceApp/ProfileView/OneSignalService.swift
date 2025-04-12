//
//  OneSignalService.swift
//  balanceApp
//
//  Created by Olkhov on 13.04.2025.
//

import Foundation
import OneSignalFramework

final class OneSignalService: NSObject, OSPushSubscriptionObserver {
    
    static let shared = OneSignalService()
    
    private var isInitialized = false
    private var hasRequestedPermission = false

    private override init() {}

    func initialize() {
        guard !isInitialized else {
            print("✅ OneSignal уже инициализирован")
            return
        }

        isInitialized = true
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        OneSignal.initialize("61e511f4-5929-448d-85f4-e5bf171f0764",
                             withLaunchOptions: nil as [UIApplication.LaunchOptionsKey: Any]?)
        
        OneSignal.User.pushSubscription.addObserver(self)
        OneSignal.User.pushSubscription.optIn()
        
        print("✅ OneSignal успешно инициализирован")
    }

    func setExternalUserId(_ phone: String) {
        guard isInitialized else {
            print("❗️OneSignal не инициализирован — не можем передать externalUserId")
            return
        }

        OneSignal.login(phone)
        print("📱 Установлен externalUserId (телефон): \(phone)")
    }
    
    
    
    func requestPermissionIfNeeded() {
        guard isInitialized else {
            print("⛔️ OneSignal не инициализирован — откладываем запрос")
            return
        }

        guard !hasRequestedPermission else {
            print("🔁 Разрешение уже запрошено")
            return
        }

        hasRequestedPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("🔔 Пользователь разрешил уведомления через UNUserNotificationCenter")
                    OneSignal.User.pushSubscription.optIn()
                } else {
                    print("❌ Пользователь отклонил уведомления")
                }
            }
        }
    }

    // MARK: - OSPushSubscriptionObserver
    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        if let playerId = state.current.id {
            savePlayerId(playerId)
        }
    }

    private func savePlayerId(_ playerId: String) {
        UserDefaults.standard.set(playerId, forKey: "OneSignalPlayerID")
        print("💾 PlayerID сохранен: \(playerId)")
    }

    func getPlayerId() -> String? {
        return UserDefaults.standard.string(forKey: "OneSignalPlayerID")
    }
}
