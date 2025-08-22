import Foundation

struct AppTransaction: Codable, Identifiable {
    let id: Int
    let amount: Double
    let type: TransactionType
    let isLoyaltyWithdraw: Bool
    let date: Date
    let abonementId: Int?
    let typeId: Int
    let visitId: Int
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
        case isLoyaltyWithdraw = "is_loyalty_withdraw"
        case date = "created_date"
        case abonementId = "abonement_id"
        case typeId = "type_id"
        case visitId = "visit_id"
    }
}

struct TransactionType: Codable {
    let id: Int
    let title: String
}


