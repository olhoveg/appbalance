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

// MARK: - AppDelegate с использованием BGAppRefreshTask

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Логируем запуск приложения
        os_log("Приложение запущено. Регистрация фоновой задачи...", log: OSLog.default, type: .info)
        
        // Регистрируем фоновую задачу с вашим уникальным идентификатором
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.balanceApp.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Планируем первое выполнение задачи
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
    
    /// Операция для обновления данных через RecordDataManager
    final class RefreshOperation: Operation, @unchecked Sendable {
        override func main() {
            os_log("Фоновая операция обновления данных началась.", log: OSLog.default, type: .info)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            // Обновляем данные записей пользователей
            RecordDataManager.shared.refreshData {
                os_log("Обновление данных в фоне завершено.", log: OSLog.default, type: .info)
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 25)
            os_log("Фоновая операция завершена.", log: OSLog.default, type: .info)
        }
    }
    
    // MARK: - RecordDataManager для обновления данных записей пользователей
    class RecordDataManager {
        static let shared = RecordDataManager()
        
        func refreshData(completion: @escaping () -> Void) {
            print("RecordDataManager: Начало обновления данных...")
            // Вызываем обновление данных из RecordViewModel
            RecordViewModel.sharedInstance.refreshData()
            // Предположим, что обновление занимает 2 секунды, затем вызываем completion
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                os_log("RecordDataManager: Данные обновлены.", log: OSLog.default, type: .info)
                completion()
            }
        }
    }
}

// MARK: - Основное приложение

@main
struct balanceAppApp: App {
    // Подключаем AppDelegate для BackgroundTasks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
            SplashScreen() // Ваш основной SwiftUI интерфейс
        }
        .modelContainer(sharedModelContainer)
    }
}
