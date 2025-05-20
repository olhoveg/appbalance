//
//  balanceAppApp.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 12.02.2025.
//

import SwiftUI
import Firebase
import SwiftData
import BackgroundTasks
import os
import UserNotifications  // Добавляем для работы с уведомлениями
import OneSignalFramework
import AppMetricaCore
import AppMetricaPush


// MARK: - AppDelegate с использованием BGAppRefreshTask и UNUserNotificationCenterDelegate

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        os_log("Приложение запущено. Регистрация фоновой задачи...", log: OSLog.default, type: .info)

        // 🔹 AppMetrica SDK
                let configuration = AppMetricaConfiguration(apiKey: "d0903bcd-73ec-46c9-988b-32582a4d7334")!
                AppMetrica.activate(with: configuration)
        AppMetrica.reportEvent(name: "Приложение запущено")
        
        AppMetricaPush.handleApplicationDidFinishLaunching(options: launchOptions)
        // Настройка цепочки делегатов для UNUserNotificationCenter
        let pushDelegate = AppMetricaPush.userNotificationCenterDelegate
        pushDelegate.nextDelegate = self
        UNUserNotificationCenter.current().delegate = pushDelegate
        
        // Запрашиваем разрешение на уведомления с задержкой
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                os_log("🔐 Разрешение на уведомления: %@", log: OSLog.default, type: .info, granted ? "разрешено" : "отказано")
                print("AppMetrica push permission status: \(granted)")
                AppMetrica.reportEvent(name: "Push (UNUserNotificationCenter): Разрешение на push-уведомления", parameters: ["разрешено": granted])
            }
        }
        
        application.registerForRemoteNotifications()
        
        // Регистрируем фоновую задачу с вашим уникальным идентификатором
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.balanceApp.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Планируем первое выполнение фоновой задачи
        scheduleAppRefresh()
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        let environment = AppMetricaPushEnvironment.development
        #else
        let environment = AppMetricaPushEnvironment.production
        #endif
        AppMetricaPush.setDeviceTokenFrom(deviceToken, pushEnvironment: environment)
        AppMetrica.reportEvent(name: "Push (AppMetrica): Устройство зарегистрировано", parameters: ["environment": environment == .production ? "production" : "development"])
    }
    
    /// Планирует выполнение фоновой задачи обновления
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourcompany.balanceApp.refresh")
        // Задача не может начаться ранее, чем через 15 минут
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled at: \(request.earliestBeginDate ?? Date())")
            AppMetrica.reportEvent(
                name: "Фоновая задача запланирована",
                parameters: ["scheduled_time": ISO8601DateFormatter().string(from: request.earliestBeginDate ?? Date())]
            )
        } catch {
            print("Could not schedule app refresh: \(error)")
            AppMetrica.reportEvent(
                name: "Фоновая задача не запланирована",
                parameters: ["error": error.localizedDescription]
            )
        }
    }
    
    /// Обработчик фоновой задачи обновления
    func handleAppRefresh(task: BGAppRefreshTask) {
        os_log("Фоновая задача получена от системы.", log: OSLog.default, type: .info)
        AppMetrica.reportEvent(name: "Фоновая задача началась")
        
        // Планируем следующую задачу
        scheduleAppRefresh()
        
        let operation = RefreshOperation()
        
        task.expirationHandler = {
            os_log("Фоновая задача истекла, отменяем выполнение.", log: OSLog.default, type: .error)
            operation.cancel()
        }
        
        operation.completionBlock = {
            let success = !operation.isCancelled
            os_log("Фоновая задача завершена. Успешно: %@", log: OSLog.default, type: .info, success ? "Да" : "Нет")
            task.setTaskCompleted(success: success)
            AppMetrica.reportEvent(
                name: "Фоновая задача завершена",
                parameters: ["success": success]
            )
        }
        
        os_log("Добавляем операцию в очередь.", log: OSLog.default, type: .info)
        OperationQueue().addOperation(operation)
    }
    
    /// Фоновая операция для обновления данных через RecordDataManager
    final class RefreshOperation: Operation, @unchecked Sendable {
        override func main() {
            os_log("Фоновая операция обновления данных началась.", log: OSLog.default, type: .info)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            // Выполняем обновление данных на главном акторе
            Task { @MainActor in
                RecordViewModel.sharedInstance.refreshData()
                semaphore.signal()
            }
            
            // Увеличил таймаут ожидания до 45 секунд (при необходимости можно увеличить)
            _ = semaphore.wait(timeout: .now() + 45)
            os_log("Фоновая операция завершена.", log: OSLog.default, type: .info)
        }
    }
    
    // MARK: - RecordDataManager для обновления данных записей пользователей
    class RecordDataManager {
        static let shared = RecordDataManager()
        
        func refreshData(completion: @escaping () -> Void) {
            print("RecordDataManager: Начало обновления данных...")
            // Выполняем обновление данных на главном акторе:
            Task { @MainActor in
                RecordViewModel.sharedInstance.refreshData()
                // Предположим, что обновление занимает 2 секунды, затем вызываем completion
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    os_log("RecordDataManager: Данные обновлены.", log: OSLog.default, type: .info)
                    completion()
                }
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // Этот метод будет вызван, когда уведомление получено, пока приложение активно (foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 [Foreground Push] Уведомление получено: \(notification.request.content.userInfo)")
        // Показываем баннер, звук и значок
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - Основное приложение

@main
@MainActor
struct balanceAppApp: App {
    // Подключаем AppDelegate для BackgroundTasks и уведомлений
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab: Tab = .main
    @State private var isSplashFinished: Bool = false

    
    // Создаем единый кэш изображений
    @StateObject private var imageCache = ImageCache.shared
    
    // Инициализация Firebase
    init() {
        FirebaseApp.configure()
        // Инициализируем OneSignal сразу при запуске приложения
        OneSignalService.shared.initialize()
        let workItem = DispatchWorkItem {
            let deviceState = OneSignal.User.pushSubscription
            AppMetrica.reportEvent(name: "Push (OneSignal): Состояние устройства",
                parameters: [
                    "userId": deviceState.id ?? "nil",
                    "isSubscribed": deviceState.optedIn
                ])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            if !isSplashFinished {
                SplashScreen()
                    .onAppear {
                        // Ждем 2 секунды, затем скрываем SplashScreen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.isSplashFinished = true
                        }
                    }
                    .environmentObject(authViewModel)
                    .environmentObject(imageCache)
            } else {
                if authViewModel.isLoggedIn {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(imageCache)
                } else {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(imageCache)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
