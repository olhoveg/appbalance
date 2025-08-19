// Abonement.swift
import Foundation

struct AbonementType: Codable {
    let title: String
}

struct AbonementStatus: Codable {
    let id: Int
    let slug: String?
    let title: String
    let extended_title: String?
}

struct BalanceLink: Codable {
    let count: Int
}

struct BalanceContainer: Codable {
    let links: [BalanceLink]
}

struct Abonement: Identifiable, Codable {
    var id: Int
    let number: String
    let type: AbonementType
    let createdDate: Date
    let expirationDate: Date?
    var transactions: [AppTransaction]?
    let initialBalance: Int?
    
    let united_balance_services_count: Int?
    let balanceString: String?
    let balanceContainer: BalanceContainer?
    let expirationText: String?

    var balance: Int {
        if let unitedBalance = united_balance_services_count {
            return unitedBalance
        }
        return balanceContainer?.links.reduce(0) { $0 + $1.count } ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, number, type, united_balance_services_count, balanceString, balanceContainer, expirationText
        case createdDate = "created_date"
        case expirationDate = "expiration_date"
        case initialBalance = "initial_balance"
    }
}

struct AbonementAPIResponse: Codable {
    let data: [Abonement]
    let meta: AbonementMeta
}

struct AbonementMeta: Codable {
    let count: Int
}
