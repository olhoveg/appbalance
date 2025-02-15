import Foundation

struct Certificate: Identifiable, Codable {
    var id: Int
    let number: String
    let balance: Int
    let defaultBalance: Int
    let typeID: Int
    let statusID: Int
    let createdDate: Date?
    let expirationDate: Date?
    
    // Добавляем imageUrl
    var imageUrl: String?

    let type: CertificateType?
    let status: CertificateStatus?

    enum CodingKeys: String, CodingKey {
        case id, number, balance, type, status
        case defaultBalance = "default_balance"
        case typeID = "type_id"
        case statusID = "status_id"
        case createdDate = "created_date"
        case expirationDate = "expiration_date"
    }
}

struct CertificateType: Codable {
    let title: String?
}

struct CertificateStatus: Codable {
    let name: String?
}
