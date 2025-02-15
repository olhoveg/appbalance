import Foundation

struct CertificateType: Codable {
    let title: String?
}

struct CertificateStatus: Codable {
    let name: String?
}

struct Certificate: Identifiable, Codable {
    var id: Int
    let number: String
    let balance: Int
    let defaultBalance: Int?
    let typeID: Int?
    let statusID: Int?
    let createdDate: Date?
    let expirationDate: Date?
    var imageUrl: String?
    var buyUrl: String?
    var expirationText: String? // новое свойство – должно идти до type и status

    let type: CertificateType?
    let status: CertificateStatus?

    enum CodingKeys: String, CodingKey {
        case id, number, balance, type, status, buyUrl, expirationText
        case defaultBalance = "default_balance"
        case typeID = "type_id"
        case statusID = "status_id"
        case createdDate = "created_date"
        case expirationDate = "expiration_date"
        case imageUrl = "image_url"
    }
}

struct APIResponse: Codable {
    let success: Bool
    let data: [Certificate]
    let meta: Meta
}

struct Meta: Codable {
    let count: Int
}
