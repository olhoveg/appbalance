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
    let isUnlimited: Bool?
    let category: ServiceCategory?
    let service: ServiceItem?
    
    enum CodingKeys: String, CodingKey {
        case count, category, service
        case isUnlimited = "is_unlimited"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decode(Int.self, forKey: .count)
        isUnlimited = try container.decodeIfPresent(Bool.self, forKey: .isUnlimited)
        category = try container.decodeIfPresent(ServiceCategory.self, forKey: .category)
        service = try container.decodeIfPresent(ServiceItem.self, forKey: .service)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(count, forKey: .count)
        try container.encodeIfPresent(isUnlimited, forKey: .isUnlimited)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(service, forKey: .service)
    }
}

struct ServiceCategory: Codable {
    let id: Int
    let title: String
    let is_category: Bool
    let category_id: Int?
    let online_sale_title: String?
    let is_chain: Bool?
    let chain_price_min: Int?
    let chain_price_max: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, is_category, category_id, online_sale_title, is_chain, chain_price_min, chain_price_max
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        is_category = try container.decode(Bool.self, forKey: .is_category)
        category_id = try container.decodeIfPresent(Int.self, forKey: .category_id)
        online_sale_title = try container.decodeIfPresent(String.self, forKey: .online_sale_title)
        is_chain = try container.decodeIfPresent(Bool.self, forKey: .is_chain)
        chain_price_min = try container.decodeIfPresent(Int.self, forKey: .chain_price_min)
        chain_price_max = try container.decodeIfPresent(Int.self, forKey: .chain_price_max)
    }
}

struct ServiceItem: Codable {
    let id: Int
    let title: String
    let is_category: Bool
    let category_id: Int?
    let online_sale_title: String?
    let is_chain: Bool?
    let chain_price_min: Int?
    let chain_price_max: Int?
    let category: ServiceCategory?
    
    enum CodingKeys: String, CodingKey {
        case id, title, is_category, category_id, online_sale_title, is_chain, chain_price_min, chain_price_max, category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        is_category = try container.decode(Bool.self, forKey: .is_category)
        category_id = try container.decodeIfPresent(Int.self, forKey: .category_id)
        online_sale_title = try container.decodeIfPresent(String.self, forKey: .online_sale_title)
        is_chain = try container.decodeIfPresent(Bool.self, forKey: .is_chain)
        chain_price_min = try container.decodeIfPresent(Int.self, forKey: .chain_price_min)
        chain_price_max = try container.decodeIfPresent(Int.self, forKey: .chain_price_max)
        category = try container.decodeIfPresent(ServiceCategory.self, forKey: .category)
    }
}

struct BalanceContainer: Codable {
    let links: [BalanceLink]
}

struct Abonement: Codable, Identifiable {
    let id: Int
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
    let status: AbonementStatus

    var balance: Int {
        if let unitedBalance = united_balance_services_count {
            return unitedBalance
        }
        return balanceContainer?.links.reduce(0) { $0 + $1.count } ?? 0
    }

    var isActive: Bool {
        // A subscription is inactive if the balance is zero or less.
        if balance <= 0 {
            return false
        }
        
        // A subscription is inactive if its expiration date is in the past.
        if let expirationDate = expirationDate, expirationDate < Date() {
            return false
        }
        
        // Otherwise, it's active.
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id, number, type, united_balance_services_count, balanceContainer, expirationText, status
        case createdDate = "created_date"
        case expirationDate = "expiration_date"
        case initialBalance = "initial_balance"
        case balanceString = "balance_string"
    }
}

struct AbonementAPIResponse: Codable {
    let data: [Abonement]
    let meta: AbonementMeta
}

struct AbonementMeta: Codable {
    let count: Int
}
