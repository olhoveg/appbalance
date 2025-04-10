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

// MARK: - AppDelegate с использованием BGAppRefreshTask и UNUserNotificationCenterDelegate

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        os_log("Приложение запущено. Регистрация фоновой задачи...", log: OSLog.default, type: .info)
        
        // Настраиваем делегат для уведомлений
        UNUserNotificationCenter.current().delegate = self
        
        // Запрашиваем разрешение на уведомления
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            os_log("🔐 Разрешение на уведомления: %@", log: OSLog.default, type: .info, granted ? "разрешено" : "отказано")
        }
        
        // Регистрируем фоновую задачу с вашим уникальным идентификатором
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.balanceApp.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Планируем первое выполнение фоновой задачи
        scheduleAppRefresh()
        
        return true
    }
    
    /// Планирует выполнение фоновой задачи обновления
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourcompany.balanceApp.refresh")
        // Задача не может начаться ранее, чем через 15 минут
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled at: \(request.earliestBeginDate ?? Date())")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    /// Обработчик фоновой задачи обновления
    func handleAppRefresh(task: BGAppRefreshTask) {
        os_log("Фоновая задача получена от системы.", log: OSLog.default, type: .info)
        
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
                        MainView(selectedTab: $selectedTab)
                            .environmentObject(authViewModel)
                            .environmentObject(imageCache)
                    }
                }
            }
            .modelContainer(sharedModelContainer)
        }
    }
