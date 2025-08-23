import Foundation

struct AppVisitResponse: Codable {
    let data: AppVisit?
}

struct AppVisit: Codable {
    let records: [AppVisitRecord]
}

struct AppVisitRecord: Codable {
    let services: [AppVisitService]
    let datetime: String
    let staff: AppVisitStaff
    let length: Int
}

struct AppVisitService: Codable {
    let id: Int
    let title: String
    let cost: Int
    let amount: Int
}

struct AppVisitStaff: Codable {
    let name: String
}
