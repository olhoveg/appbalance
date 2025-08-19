import Foundation

private let API_KEY = "88fnh8jbmt44er5y28nj"

struct AbonementTransaction: Codable, Identifiable {
    let id: Int
    let amount: Double
    let date: Date
    let service: String
}

struct AbonementTransactionResponse: Codable {
    let data: [AbonementTransaction]
}
