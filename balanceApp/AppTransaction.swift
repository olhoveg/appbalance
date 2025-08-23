import Foundation

struct AppTransaction: Codable, Identifiable {
    let id: Int
    let visitId: Int
    let statusId: Int
    let amount: Double
    let typeId: Int
    let cardId: Int?
    let programId: Int?
    let certificateId: Int?
    let abonementId: Int?
    let salonGroupId: Int?
    let itemId: Int?
    let itemTypeId: Int?
    let itemRecordId: Int?
    let goodsTransactionId: Int?
    let servicesTransactionId: Int?
    let isDiscount: Bool
    let isLoyaltyWithdraw: Bool
    let type: TransactionType
    let date: Date
    var serviceTitle: String?
    var visitDetails: VisitDetails?

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
        case visitId = "visit_id"
        case statusId = "status_id"
        case typeId = "type_id"
        case cardId = "card_id"
        case programId = "program_id"
        case certificateId = "certificate_id"
        case abonementId = "abonement_id"
        case salonGroupId = "salon_group_id"
        case itemId = "item_id"
        case itemTypeId = "item_type_id"
        case itemRecordId = "item_record_id"
        case goodsTransactionId = "goods_transaction_id"
        case servicesTransactionId = "services_transaction_id"
        case isDiscount = "is_discount"
        case isLoyaltyWithdraw = "is_loyalty_withdraw"
        case date = "created_date"
    }
}

struct TransactionType: Codable {
    let id: Int
    let title: String
}


