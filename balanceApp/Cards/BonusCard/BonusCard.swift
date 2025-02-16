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
    let transactions: [BonusCardTransaction]? // История операций (если есть)
    
    enum CodingKeys: String, CodingKey {
        case id, number, balance, points
        case paidAmount = "paid_amount"
        case soldAmount = "sold_amount"
        case visitsCount = "visits_count"
        case typeId = "type_id"
        case salonGroupId = "salon_group_id"
        case maxDiscountPercent = "max_discount_percent"
        case maxDiscountAmount = "max_discount_amount"
        case type, transactions
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

struct BonusCardTransaction: Identifiable, Codable {
    var id: UUID = UUID()
    let type: String // Например, "Начисление" или "Списание"
    let amount: Double
    let date: Date

    enum CodingKeys: String, CodingKey {
        case type, amount, date
    }
}

struct BonusAPIResponse: Codable {
    let success: Bool
    let data: [BonusCard]
}
