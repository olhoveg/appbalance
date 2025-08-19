import Foundation

struct BonusCard: Identifiable, Codable {
    let id: Int
    let number: String
    let balance: Double
    let points: Int?
    let paidAmount: Int?
    let soldAmount: Int?
    let visitsCount: Int?
    let typeId: Int?
    let salonGroupId: Int?
    let maxDiscountPercent: Int?
    let maxDiscountAmount: Int?
    let type: BonusCardType
    var transactions: [AppTransaction]? // Обновлено для соответствия API
    let programs: [LoyaltyProgram]? // Программы лояльности
    
    enum CodingKeys: String, CodingKey {
        case id, number, balance, points
        case paidAmount = "paid_amount"
        case soldAmount = "sold_amount"
        case visitsCount = "visits_count"
        case typeId = "type_id"
        case salonGroupId = "salon_group_id"
        case maxDiscountPercent = "max_discount_percent"
        case maxDiscountAmount = "max_discount_amount"
        case type, transactions, programs
    }
}

struct BonusCardType: Codable {
    let id: Int
    let title: String
    let salonGroupId: Int
    let serviceItemType: String
    let goodItemType: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case salonGroupId = "salon_group_id"
        case serviceItemType = "service_item_type"
        case goodItemType = "good_item_type"
    }
}

struct AppTransaction: Codable, Identifiable {
    let id: Int
    let amount: Double
    let type: TransactionType
    let isLoyaltyWithdraw: Bool
    let date: Date
    let abonementId: Int?

    var isCredit: Bool {
        // We assume that if a transaction is not a withdrawal, it's a credit.
        return !isLoyaltyWithdraw
    }

    var formattedAmount: String {
        let sign = isCredit ? "+" : "-"
        return "\(sign)\(String(format: "%.2f", amount))"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, type
        case isLoyaltyWithdraw = "is_loyalty_withdraw"
        case date = "created_date"
        case abonementId = "abonement_id"
    }
}

struct TransactionType: Codable {
    let id: Int
    let title: String
}

struct BonusAPIResponse: Codable {
    let success: Bool
    let data: [BonusCard]
}

struct TransactionAPIResponse: Codable {
    let success: Bool
    let data: [AppTransaction]
    let meta: TransactionMeta
}

struct TransactionMeta: Codable {
    let count: Int
}

// Модели данных для программ лояльности
struct LoyaltyProgram: Codable, Identifiable {
    let id: Int
    let title: String
    let type: String
    let loyaltyTypeId: Int
    let itemTypeId: Int
    let serviceItemType: String
    let goodItemType: String
    let valueUnitId: Int
    let valueUnit: String
    let groupId: Int
    let usageLimit: Int
    let visitMultiplicity: Int
    let soldItemsMultiplicity: Int
    let currentPackageProgress: Int
    let allowedUsagesAmount: Int
    let expirationTimeout: Int
    let expirationTimeoutUnit: String?
    let expirationNotificationTimeout: Int
    let paramsSourceType: String
    let historyStartDate: String?
    let onChangedNotificationTemplateId: Int
    let onExpirationNotificationTemplateId: Int
    let value: Int
    let loyaltyType: LoyaltyType
    let rules: [LoyaltyRule]
    
    enum CodingKeys: String, CodingKey {
        case id, title, type, value
        case loyaltyTypeId = "loyalty_type_id"
        case itemTypeId = "item_type_id"
        case serviceItemType = "service_item_type"
        case goodItemType = "good_item_type"
        case valueUnitId = "value_unit_id"
        case valueUnit = "value_unit"
        case groupId = "group_id"
        case usageLimit = "usage_limit"
        case visitMultiplicity = "visit_multiplicity"
        case soldItemsMultiplicity = "sold_items_multiplicity"
        case currentPackageProgress = "current_package_progress"
        case allowedUsagesAmount = "allowed_usages_amount"
        case expirationTimeout = "expiration_timeout"
        case expirationTimeoutUnit = "expiration_timeout_unit"
        case expirationNotificationTimeout = "expiration_notification_timeout"
        case paramsSourceType = "params_source_type"
        case historyStartDate = "history_start_date"
        case onChangedNotificationTemplateId = "on_changed_notification_template_id"
        case onExpirationNotificationTemplateId = "on_expiration_notification_template_id"
        case loyaltyType = "loyalty_type"
        case rules
    }
}

struct LoyaltyType: Codable {
    let id: Int
    let slug: String
    let title: String
    let isDiscount: Bool
    let isCashback: Bool
    let isStatic: Bool
    let isAccumulative: Bool
    let isVisitLimited: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, slug, title
        case isDiscount = "is_discount"
        case isCashback = "is_cashback"
        case isStatic = "is_static"
        case isAccumulative = "is_accumulative"
        case isVisitLimited = "is_visit_limited"
    }
}

struct LoyaltyRule: Codable, Identifiable {
    let id: Int
    let loyaltyProgramId: Int
    let loyaltyTypeId: Int
    let value: Int
    let parameter: Int
    let serviceId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, value, parameter
        case loyaltyProgramId = "loyalty_program_id"
        case loyaltyTypeId = "loyalty_type_id"
        case serviceId = "service_id"
    }
}
