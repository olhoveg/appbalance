//
//  APIResponse.swift
//  balanceApp
//
//  Created by Evgen on 15.02.2025.
//

import Foundation

struct APIResponse: Codable {
    let success: Bool
    let data: [Certificate]
    let meta: Meta
}

struct Meta: Codable {
    let count: Int
}
