import Foundation
import UIKit
import YooKassaPayments

class YooKassaRealPaymentService: ObservableObject {
	static let shared = YooKassaRealPaymentService()
	
	private init() {
		// Настраиваем обработку возврата в приложение
		setupAppReturnHandling()
	}
	
	private func setupAppReturnHandling() {
		// Обработка возврата в приложение через URL схему
		NotificationCenter.default.addObserver(
			forName: UIApplication.didBecomeActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			// Когда приложение становится активным (возврат из браузера),
			// проверяем, есть ли активный платеж для проверки статуса
			if let self = self, let paymentId = self.lastPaymentId {
				print("🔄 Приложение стало активным, проверяем статус платежа: \(paymentId)")
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					self.startPaymentStatusCheck(paymentId: paymentId)
				}
			}
		}
	}
	
	private weak var presentedModule: (UIViewController & TokenizationModuleInput)?
	private var lastPaymentId: String?
	private var pendingAmount: Decimal = 0
	private var pendingDescription: String = ""
	private var statusCheckAttempts: Int = 0
	private let maxStatusCheckAttempts: Int = 20
	
	// Защита от множественных уведомлений
	private var processedPaymentIds: Set<String> = []
	
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
				clientApplicationKey: "live_MTE0NTc4MM6FE0QDt7-dK7d9_HajywyAQOzaAsNrmok",
				shopName: "BalanceApp",
				shopId: "1145780",
				purchaseDescription: "Покупка видео урока",
				amount: Amount(value: Decimal(lesson.currentPrice), currency: .rub),
				tokenizationSettings: TokenizationSettings(paymentMethodTypes: [.sbp, .bankCard, .sberbank]),
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
		let status: String?
		let id: String?
		let confirmation: Confirmation?
		let type: String?
		let description: String?
		let code: String?
		
		var paymentId: String? { id }
		var confirmationUrl: String? { confirmation?.confirmationUrl }
		var isError: Bool { type == "error" }
		
		// Игнорируем неизвестные поля
		private enum CodingKeys: String, CodingKey {
			case status, id, confirmation, type, description, code
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			status = try container.decodeIfPresent(String.self, forKey: .status)
			id = try container.decodeIfPresent(String.self, forKey: .id)
			confirmation = try container.decodeIfPresent(Confirmation.self, forKey: .confirmation)
			type = try container.decodeIfPresent(String.self, forKey: .type)
			description = try container.decodeIfPresent(String.self, forKey: .description)
			code = try container.decodeIfPresent(String.self, forKey: .code)
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
			"returnUrl": "balanceapp://payment-return",
			"paymentMethodType": paymentMethodType.rawValue
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
	
	private func sendSuccessNotification(paymentId: String) {
		// Проверяем, не отправляли ли мы уже уведомление для этого платежа
		guard !processedPaymentIds.contains(paymentId) else {
			print("⚠️ Уведомление об успехе для платежа \(paymentId) уже было отправлено, пропускаем")
			return
		}
		
		// Добавляем в список обработанных
		processedPaymentIds.insert(paymentId)
		
		print("🎉 Отправляем уведомление об успешном платеже: \(paymentId)")
		NotificationCenter.default.post(name: .ykPaymentSuccess, object: nil, userInfo: ["token": paymentId])
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
		print("   Payment Method Type Raw Value: \(paymentMethodType.rawValue)")
		print("   Is SBP: \(paymentMethodType == .sbp)")
		print("   Is Sberbank: \(paymentMethodType == .sberbank)")
		print("   Is BankCard: \(paymentMethodType == .bankCard)")
		print("   Amount: \(pendingAmount)")
		print("   Description: \(pendingDescription)")
		print("   🔍 Проверяем все возможные типы Tinkoff:")
		print("   - Contains 'tinkoff' in raw value: \(paymentMethodType.rawValue.lowercased().contains("tinkoff"))")
		print("   - Contains 'tpay' in raw value: \(paymentMethodType.rawValue.lowercased().contains("tpay"))")
		print("   - Contains 'bank' in raw value: \(paymentMethodType.rawValue.lowercased().contains("bank"))")
		
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
					// Проверяем, является ли ответ ошибкой
					if response.isError {
						print("❌ Ошибка от YooKassa API:")
						print("   Type: \(response.type ?? "nil")")
						print("   Code: \(response.code ?? "nil")")
						print("   Description: \(response.description ?? "nil")")
						
						if let module = self.presentedModule {
							module.dismiss(animated: true)
							self.presentedModule = nil
						}
						
						let errorMessage = response.description ?? "Ошибка создания платежа"
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
						return
					}
					
					print("✅ Платеж успешно создан на бэкенде:")
					print("   Status: \(response.status ?? "nil")")
					print("   Payment ID: \(response.paymentId ?? "nil")")
					print("   Confirmation URL: \(response.confirmationUrl ?? "nil")")
					
					self.lastPaymentId = response.paymentId
					// Не закрываем модуль токенизации: он потребуется для startConfirmationProcess
					
					// Безопасная проверка статуса
					guard let status = response.status else {
						print("❌ Ошибка: отсутствует статус платежа")
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
						return
					}
					
					let lowerStatus = status.lowercased()
					if lowerStatus == "succeeded" {
						print("🎉 Платеж уже выполнен, отправляем уведомление об успехе")
						self.sendSuccessNotification(paymentId: response.paymentId ?? "")
					} else if lowerStatus == "pending" {
						// Для всех типов платежей проверяем наличие URL подтверждения
						if let urlStr = response.confirmationUrl, !urlStr.isEmpty {
							if paymentMethodType == .bankCard {
								print("🔄 Bank card: подтверждение внутри SDK")
								if let module = self.presentedModule {
									module.startConfirmationProcess(confirmationUrl: urlStr, paymentMethodType: paymentMethodType)
								} else {
									print("❌ Ошибка: модуль токенизации недоступен для подтверждения")
									NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
								}
							} else {
								// Все остальные методы (SBP, SberPay, Tinkoff Bank и др.) - открываем подтверждение вне SDK
								print("🔄 \(paymentMethodType.rawValue): открываем подтверждение вне SDK")
								if let url = URL(string: urlStr) {
									UIApplication.shared.open(url) { success in
										if success {
											print("✅ Успешно открыт URL для подтверждения")
											// Закрываем модуль токенизации, так как пользователь уходит во внешний браузер
											if let module = self.presentedModule {
												module.dismiss(animated: true)
												self.presentedModule = nil
											}
											DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
												self.startPaymentStatusCheck(paymentId: response.paymentId ?? "")
											}
										} else {
											print("❌ Не удалось открыть URL для подтверждения")
											NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
										}
									}
								} else {
									print("❌ Неверный URL для подтверждения: \(urlStr)")
									NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.tokenizationError])
								}
							}
						} else {
							print("⏳ Платеж в обработке без подтверждения, начинаем проверку статуса")
							// Начинаем проверку статуса платежа
							self.startPaymentStatusCheck(paymentId: response.paymentId ?? "")
						}
					} else {
						print("❌ Неожиданный статус платежа: \(status)")
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
		print("   Error type: \(type(of: error))")
		print("   Error description: \(error.localizedDescription)")
		
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
		
		// Проверяем, является ли это отменой пользователем
		let errorDescription = error.localizedDescription.lowercased()
		print("   Analyzing tokenization error: '\(errorDescription)'")
		
		// Если это ошибка валидации или другая техническая ошибка, показываем её
		if errorDescription.contains("validation") ||
		   errorDescription.contains("network") ||
		   errorDescription.contains("server") ||
		   errorDescription.contains("invalid") {
			print("❌ Реальная ошибка токенизации")
			NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
		} else {
			// Все остальные ошибки считаем отменой пользователя
			print("🚫 Пользователь отменил платеж (tokenization)")
			NotificationCenter.default.post(name: .ykPaymentCanceled, object: nil)
		}
	}
	
	func didFinish(on module: TokenizationModuleInput) {
		print("✅ Токенизация завершена успешно")
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
		// Отправляем уведомление об отмене платежа, чтобы сбросить состояние загрузки
		NotificationCenter.default.post(name: .ykPaymentCanceled, object: nil)
	}
	
	func didFinish(on module: TokenizationModuleInput, with error: YooKassaPaymentsError?) {
		print("❌ Токенизация завершена с ошибкой: \(error?.localizedDescription ?? "неизвестная ошибка")")
		print("   Error type: \(type(of: error))")
		print("   Error description: \(error?.localizedDescription ?? "nil")")
		
		if let module = presentedModule {
			module.dismiss(animated: true)
			presentedModule = nil
		}
		
		// Поскольку этот метод вызывается при закрытии модуля, 
		// считаем все ошибки отменой пользователя (кроме явных технических ошибок)
		if let yooKassaError = error {
			let errorDescription = yooKassaError.localizedDescription.lowercased()
			print("   Analyzing error: '\(errorDescription)'")
			
			// Только явные технические ошибки считаем реальными ошибками
			if errorDescription.contains("validation") ||
			   errorDescription.contains("network") ||
			   errorDescription.contains("server") ||
			   errorDescription.contains("invalid") ||
			   errorDescription.contains("connection") {
				print("❌ Реальная ошибка платежа")
				NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": yooKassaError])
			} else {
				// Все остальные ошибки при закрытии модуля считаем отменой пользователя
				print("🚫 Пользователь отменил платеж (закрытие модуля)")
				NotificationCenter.default.post(name: .ykPaymentCanceled, object: nil)
			}
		} else {
			// Если ошибка nil, точно отмена пользователя
			print("🚫 Пользователь отменил платеж (ошибка nil)")
			NotificationCenter.default.post(name: .ykPaymentCanceled, object: nil)
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
						self.sendSuccessNotification(paymentId: paymentId)
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
										self.sendSuccessNotification(paymentId: paymentId)
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
		// Отправляем уведомление об отмене платежа, чтобы сбросить состояние загрузки
		NotificationCenter.default.post(name: .ykPaymentCanceled, object: nil)
	}
}

// MARK: - Payment Status Check
extension YooKassaRealPaymentService {
	private func startPaymentStatusCheck(paymentId: String) {
		print("🔄 Начинаем проверку статуса платежа: \(paymentId)")
		
		// Сбрасываем счетчик попыток
		statusCheckAttempts = 0
		
		// Запускаем первую проверку
		checkPaymentStatusRecursively(paymentId: paymentId)
	}
	
	private func checkPaymentStatusRecursively(paymentId: String) {
		fetchPaymentStatus(paymentId: paymentId) { [weak self] result in
			guard let self = self else { return }
			
			DispatchQueue.main.async {
				switch result {
				case .success(let status):
					print("📊 Статус платежа: \(status)")
					let lowerStatus = status.lowercased()
					
					switch lowerStatus {
					case "succeeded":
						print("🎉 Платеж успешно подтвержден")
						// Очищаем lastPaymentId после успешного завершения
						self.lastPaymentId = nil
						self.sendSuccessNotification(paymentId: paymentId)
					case "pending":
						self.statusCheckAttempts += 1
						
						if self.statusCheckAttempts >= self.maxStatusCheckAttempts {
							print("❌ Превышено максимальное количество попыток проверки статуса")
							// Очищаем lastPaymentId после неудачного завершения
							self.lastPaymentId = nil
							NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
							return
						}
						
						print("⏳ Платеж в обработке, попытка \(self.statusCheckAttempts)/\(self.maxStatusCheckAttempts)")
						// Повторяем проверку через 5 секунд
						DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
							self.checkPaymentStatusRecursively(paymentId: paymentId)
						}
					case "canceled":
						print("❌ Платеж отменен")
						// Очищаем lastPaymentId после отмены
						self.lastPaymentId = nil
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
					default:
						print("❌ Неизвестный статус платежа: \(status)")
						// Очищаем lastPaymentId после неизвестного статуса
						self.lastPaymentId = nil
						NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": YooPaymentError.validationError])
					}
				case .failure(let error):
					print("❌ Ошибка проверки статуса: \(error)")
					// Очищаем lastPaymentId после ошибки
					self.lastPaymentId = nil
					NotificationCenter.default.post(name: .ykPaymentError, object: nil, userInfo: ["error": error])
				}
			}
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
