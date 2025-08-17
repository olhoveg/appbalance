import Foundation
import UIKit
import YooKassaPayments

class YooKassaRealPaymentService: ObservableObject {
	static let shared = YooKassaRealPaymentService()
	
	private init() {}
	
	private weak var presentedModule: (UIViewController & TokenizationModuleInput)?
	private var lastPaymentId: String?
	private var pendingAmount: Decimal = 0
	private var pendingDescription: String = ""
	private var statusCheckAttempts: Int = 0
	private let maxStatusCheckAttempts: Int = 10
	
	private var backendBaseURL: String? {
		Bundle.main.object(forInfoDictionaryKey: "PaymentsBackendURL") as? String
	}
	
	// MARK: - Создание платежа
	func createPayment(
		for lesson: VideoLesson,
		userPhone: String,
		completion: @escaping (Result<String, Error>) -> Void
	) {
		print("🚀 Начинаем создание платежа для урока: \(lesson.title)")
		print("   Цена: \(lesson.currentPrice)")
		print("   Телефон пользователя: \(userPhone)")
		
		// Используем реальный YooKassa SDK во всех случаях
		print("🚀 Используем реальный YooKassa SDK")
		
		// Проверяем входные данные
		guard lesson.currentPrice > 0 else {
			print("❌ Ошибка: некорректная цена урока")
			completion(.failure(YooPaymentError.tokenizationError))
			return
		}
		
		// Сохраняем сумму и описание для вызова бэкенда после токенизации
		pendingAmount = Decimal(lesson.currentPrice)
		pendingDescription = "Оплата в BalanceApp: \(lesson.title) (телефон: \(userPhone), ID: \(lesson.id))"
		
		do {
			let inputData = TokenizationModuleInputData(
				clientApplicationKey: "test_NzczNzU3V4O1jhaBdcAJ927ujxZKwYPRNm1lNvYbsfE",
				shopName: "BalanceApp",
				shopId: "773757",
				purchaseDescription: "Покупка видео урока",
				amount: Amount(value: Decimal(lesson.currentPrice), currency: .rub),
				tokenizationSettings: TokenizationSettings(paymentMethodTypes: PaymentMethodTypes.all),
				testModeSettings: TestModeSettings(
					paymentAuthorizationPassed: true,
					cardsCount: 1,
					charge: Amount(value: 1, currency: .rub),
					enablePaymentError: false
				),
				isLoggingEnabled: true,
				savePaymentMethod: .off,
				applicationScheme: "balanceapp://"
			)
			
			let flow = TokenizationFlow.tokenization(inputData)
			let tokenizationModule = TokenizationAssembly.makeModule(
				inputData: flow,
				moduleOutput: self
			)
			
			self.presentedModule = tokenizationModule
			
			DispatchQueue.main.async {
				if let presenter = self.getTopViewController() {
					print("✅ Презентуем экран оплаты")
					presenter.present(tokenizationModule, animated: true)
				} else {
					print("❌ Ошибка: не удалось получить top view controller")
					completion(.failure(YooPaymentError.presentationError))
				}
			}
		} catch {
			print("❌ Ошибка при создании input data: \(error)")
			completion(.failure(error))
		}
	}
	
	// MARK: - Backend calls
	private struct CreatePaymentResponse: Decodable {
		let status: String
		let id: String?
		let confirmation: Confirmation?
		
		var paymentId: String? { id }
		var confirmationUrl: String? { confirmation?.confirmationUrl }
		
		// Игнорируем неизвестные поля
		private enum CodingKeys: String, CodingKey {
			case status, id, confirmation
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			status = try container.decode(String.self, forKey: .status)
			id = try container.decodeIfPresent(String.self, forKey: .id)
			confirmation = try container.decodeIfPresent(Confirmation.self, forKey: .confirmation)
		}
	}
	
	private struct Confirmation: Decodable {
		let confirmationUrl: String?
		
		enum CodingKeys: String, CodingKey {
			case confirmationUrl = "confirmation_url"
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			confirmationUrl = try container.decodeIfPresent(String.self, forKey: .confirmationUrl)
		}
	}
	
	private func formatAmountString(_ amount: Decimal) -> String {
		let formatter = NumberFormatter()
		formatter.decimalSeparator = "."
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
		formatter.minimumIntegerDigits = 1
		return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
	}
	
	private func createPaymentViaBackend(token: Tokens, amount: Decimal, description: String, paymentMethodType: PaymentMethodType, completion: @escaping (Result<CreatePaymentResponse, Error>) -> Void) {
		guard let base = backendBaseURL, let url = URL(string: base + "/payments/create") else {
			print("❌ Ошибка: не удалось создать URL для бэкенда")
			completion(.failure(YooPaymentError.tokenizationError))
			return
		}
		
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let body: [String: Any] = [
			"sdkToken": token.paymentToken,
			"amount": formatAmountString(amount),
			"description": description,
			"returnUrl": "balanceapp://payment-return"
		]
		
		print("📤 Отправляем запрос на бэкенд:")
		print("   URL: \(url)")
		print("   Body: \(body)")
		
		req.httpBody = try? JSONSerialization.data(withJSONObject: body)
		
		URLSession.shared.dataTask(with: req) { data, response, err in
			if let err = err { 
				print("❌ Ошибка сети: \(err)")
				completion(.failure(err)); 
				return 
			}
			
			if let httpResponse = response as? HTTPURLResponse {
				print("📥 Получен ответ от бэкенда:")
				print("   Status: \(httpResponse.statusCode)")
				print("   Headers: \(httpResponse.allHeaderFields)")
			}
			
			guard let data = data, data.count > 0 else { 
				print("❌ Ошибка: пустой ответ от бэкенда")
				completion(.failure(YooPaymentError.tokenizationError)); 
				return 
			}
			
			print("📄 Данные ответа: \(String(data: data, encoding: .utf8) ?? "неизвестно")")
			
			do {
				let resp = try JSONDecoder().decode(CreatePaymentResponse.self, from: data)
				print("✅ Успешно декодирован ответ:")
				print("   Status: \(resp.status)")
				print("   Payment ID: \(resp.paymentId ?? "nil")")
				print("   Confirmation URL: \(resp.confirmationUrl ?? "nil")")
				completion(.success(resp))
			} catch {
				print("❌ Ошибка декодирования: \(error)")
				completion(.failure(error))
			}
		}.resume()
	}
	
	private func fetchPaymentStatus(paymentId: String, completion: @escaping (Result<String, Error>) -> Void) {
		guard let base = backendBaseURL, let url = URL(string: base + "/payments/status?payment_id=\(paymentId)") else {
			print("❌ Ошибка: не удалось создать URL для проверки статуса")
			completion(.failure(YooPaymentError.validationError))
			return
		}
		
		var req = URLRequest(url: url)
		req.httpMethod = "GET"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		print("📤 Проверяем статус платежа:")
		print("   URL: \(url)")
		
		URLSession.shared.dataTask(with: req) { data, response, err in
			if let err = err {
				print("❌ Ошибка сети при проверке статуса: \(err)")
				completion(.failure(err))
				return
			}
			
			if let httpResponse = response as? HTTPURLResponse {
				print("📥 Получен ответ от бэкенда:")
				print("   Status: \(httpResponse.statusCode)")
				
				if httpResponse.statusCode != 200 {
					print("❌ HTTP ошибка: \(httpResponse.statusCode)")
					completion(.failure(YooPaymentError.validationError))
					return
				}
			}
			
			guard let data = data, data.count > 0 else {
				print("❌ Ошибка: пустой ответ при проверке статуса")
				completion(.failure(YooPaymentError.validationError))
				return
			}
			
			print("📄 Данные ответа статуса: \(String(data: data, encoding: .utf8) ?? "неизвестно")")
			
			do {
				let statusResponse = try JSONDecoder().decode(StatusResponse.self, from: data)
				print("✅ Статус платежа: \(statusResponse.status)")
				completion(.success(statusResponse.status))
			} catch {
				print("❌ Ошибка декодирования статуса: \(error)")
				completion(.failure(error))
			}
		}.resume()
	}
	
	private struct StatusResponse: Decodable {
		let status: String
		let payment_id: String?
	}
	
	// MARK: - Helpers
	private func getTopViewController() -> UIViewController? {
		guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		      let window = windowScene.windows.first else {
			return nil
		}
		var topViewController = window.rootViewController
		while let presentedViewController = topViewController?.presentedViewController {
			topViewController = presentedViewController
		}
		return topViewController
	}
}

// MARK: - TokenizationModuleOutput (SDK 8.0.1)
extension YooKassaRealPaymentService: TokenizationModuleOutput {
	func tokenizationModule(
		_ module: TokenizationModuleInput,
		didTokenize token: Tokens,
		paymentMethodType: PaymentMethodType
	) {
		print("🎯 Получен токен от YooKassa SDK:")
		print("   Payment Token: \(token.paymentToken)")
		print("   Payment Method Type: \(paymentMethodType)")
		print("   Amount: \(pendingAmount)")
		print("   Description: \(pendingDescription)")
		
		// Проверяем, что у нас есть все необходимые данные
		guard !token.paymentToken.isEmpty else {
			print("❌ Ошибка: пустой payment token")
			presentedModule?.dismiss(animated: true)
			presentedModule = nil
			NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
			return
		}
		
		// 1) Создаём платёж на бэкенде
		createPaymentViaBackend(token: token, amount: pendingAmount, description: pendingDescription, paymentMethodType: paymentMethodType) { [weak self] result in
			DispatchQueue.main.async {
				guard let self = self else { 
					print("❌ Ошибка: self is nil в completion")
					return 
				}
				
				switch result {
				case .success(let response):
					print("✅ Платеж успешно создан на бэкенде:")
					print("   Status: \(response.status)")
					print("   Payment ID: \(response.paymentId ?? "nil")")
					print("   Confirmation URL: \(response.confirmationUrl ?? "nil")")
					
					self.lastPaymentId = response.paymentId
					
					// Безопасная проверка статуса
					let status = response.status.lowercased()
					if status == "succeeded" {
						print("🎉 Платеж уже выполнен, отправляем уведомление об успехе")
						if let module = self.presentedModule {
							module.dismiss(animated: true)
							self.presentedModule = nil
						}
						NotificationCenter.default.post(name: .ykPaymentSuccess, object: nil, userInfo: ["token": response.paymentId ?? token.paymentToken])
					} else if let urlStr = response.confirmationUrl, !urlStr.isEmpty {
						print("🔄 Требуется подтверждение, запускаем процесс подтверждения")
						// 2) Запускаем подтверждение (3DS/SBP), SDK 8.0.1 ожидает String
						// Проверяем, что модуль все еще активен перед вызова startConfirmationProcess
						if let module = self.presentedModule {
							module.startConfirmationProcess(confirmationUrl: urlStr, paymentMethodType: paymentMethodType)
						} else {
							print("❌ Ошибка: модуль токенизации уже отключен")
							NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
						}
					} else {
						print("❌ Неожиданный статус платежа: \(response.status)")
						if let module = self.presentedModule {
							module.dismiss(animated: true)
							self.presentedModule = nil
						}
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
					}
				case .failure(let error):
					print("❌ Ошибка создания платежа: \(error)")
					if let module = self.presentedModule {
						module.dismiss(animated: true)
						self.presentedModule = nil
					}
					NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
				}
			}
		}
	}
	
	func tokenizationModule(
		_ module: TokenizationModuleInput,
		didFailTokenize error: Error
	) {
		print("❌ Ошибка токенизации: \(error)")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
		NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
	}
	
	func didFinish(on module: TokenizationModuleInput) {
		print("✅ Токенизация завершена успешно")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
	}
	
	func didFinish(on module: TokenizationModuleInput, with error: YooKassaPaymentsError?) {
		print("❌ Токенизация завершена с ошибкой: \(error?.localizedDescription ?? "неизвестная ошибка")")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
	}
	
	func didFinishConfirmation(paymentMethodType: PaymentMethodType) {
		print("✅ Подтверждение платежа завершено")
		print("   Payment Method Type: \(paymentMethodType)")
		print("   Last Payment ID: \(lastPaymentId ?? "nil")")
		
		guard let paymentId = lastPaymentId else {
			print("❌ Ошибка: отсутствует payment ID")
			if let module = presentedModule {
				module.dismiss(animated: true)
				presentedModule = nil
			}
			NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
			return
		}
		
		// Сбрасываем счетчик попыток проверки
		statusCheckAttempts = 0
		print("🔄 Проверяем статус платежа: \(paymentId)")
		
		// Запускаем первую проверку статуса
		fetchPaymentStatus(paymentId: paymentId) { [weak self] result in
			DispatchQueue.main.async {
				guard let self = self else { 
					print("❌ Self is nil в completion")
					return 
				}
				
				print("📥 Получен результат проверки статуса")
				if let module = self.presentedModule {
					module.dismiss(animated: true)
					self.presentedModule = nil
				}
				
				switch result {
				case .success(let status):
					print("📊 Статус платежа: \(status)")
					let lowerStatus = status.lowercased()
					
					switch lowerStatus {
					case "succeeded":
						print("🎉 Платеж успешно подтвержден")
						NotificationCenter.default.post(name: .ykPaymentSuccess, object: nil, userInfo: ["token": paymentId])
					case "pending":
						print("⏳ Платеж в обработке, ожидаем подтверждения")
						self.statusCheckAttempts += 1
						
						if self.statusCheckAttempts >= self.maxStatusCheckAttempts {
							print("❌ Превышено максимальное количество попыток проверки статуса")
							NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
							return
						}
						
						print("🔄 Попытка \(self.statusCheckAttempts)/\(self.maxStatusCheckAttempts), повторяем через 2 секунды")
						// Повторяем проверку через 2 секунды
						DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
							self.fetchPaymentStatus(paymentId: paymentId) { result in
								// Обрабатываем результат рекурсивно
								switch result {
								case .success(let status):
									if status.lowercased() == "succeeded" {
										print("🎉 Платеж успешно подтвержден")
										NotificationCenter.default.post(name: .ykPaymentSuccess, object: nil, userInfo: ["token": paymentId])
									} else if status.lowercased() == "pending" && self.statusCheckAttempts < self.maxStatusCheckAttempts {
										// Продолжаем проверку
										self.statusCheckAttempts += 1
										DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
											self.fetchPaymentStatus(paymentId: paymentId) { _ in }
										}
									} else {
										print("❌ Платеж не подтвержден, статус: \(status)")
										NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
									}
								case .failure(let error):
									print("❌ Ошибка проверки статуса: \(error)")
									NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
								}
							}
						}
					case "canceled":
						print("❌ Платеж отменен")
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
					default:
						print("❌ Неизвестный статус платежа: \(status)")
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
					}
				case .failure(let error):
					print("❌ Ошибка проверки статуса: \(error)")
					NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
				}
			}
		}
	}
	
	func didFailConfirmation(error: YooKassaPaymentsError?) {
		print("❌ Ошибка подтверждения платежа: \(error?.localizedDescription ?? "неизвестная ошибка")")
		print("   Error: \(String(describing: error))")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
		NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error ?? YooPaymentError.validationError])
	}
	
	func tokenizationModuleDidFinish(
		_ module: TokenizationModuleInput,
		error: YooKassaPaymentsError?
	) {
		print("🏁 Модуль токенизации завершен")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
	}
}

// MARK: - Ошибки
enum YooPaymentError: Error, LocalizedError {
	case presentationError
	case tokenizationError
	case validationError
	
	var errorDescription: String? {
		switch self {
		case .presentationError:
			return "Ошибка отображения экрана оплаты"
		case .tokenizationError:
			return "Ошибка создания платежа"
		case .validationError:
			return "Ошибка валидации данных"
		}
	}
}
