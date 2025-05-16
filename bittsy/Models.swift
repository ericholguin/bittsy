//
//  Models.swift
//  bittsy
//
//  Created by eric on 4/6/25.
//

import Foundation

// API response models
struct CoinbaseResponse: Codable {
    let data: CoinbasePrice
}

struct CoinbasePrice: Codable {
    let amount: String
}

struct CoinGeckoResponse: Codable {
    let bitcoin: [String: Double]
}

// API source options
enum APISource: String, CaseIterable {
    case coinbase = "Coinbase"
    case coingecko = "CoinGecko"
    
    var logoName: String {
        switch self {
        case .coinbase: return "Coinbase"
        case .coingecko: return "CoinGecko"
        }
    }
}
