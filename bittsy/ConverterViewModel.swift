//
//  ConverterViewModel.swift
//  bittsy
//
//  Created by eric on 4/6/25.
//

import Foundation
import SwiftUI

class ConverterViewModel: ObservableObject {
    // Which field is currently active
    enum ActiveField {
        case top, bottom
    }
    
    // Mode for conversion
    enum ConversionMode {
        case fiatToBTC  // Fiat on top, BTC/Sats on bottom
        case BTCToFiat  // BTC/Sats on top, Fiat on bottom
    }
    
    @Published var topAmount: String = ""
    @Published var bottomAmount: String = ""
    @Published var activeField: ActiveField = .top
    @Published var conversionMode: ConversionMode = .fiatToBTC
    @Published var lastUpdated: Date? = nil
    @Published var btcPrice: Double? = nil {
        didSet {
            if let btcPrice = btcPrice {
                cachePrice(btcPrice)
                if activeField == .top {
                    calculateBottomFromTop()
                } else {
                    calculateTopFromBottom()
                }
            }
        }
    }
    
    @Published var topSymbol: String = "USD"
    @Published var bottomSymbol: String = "BTC"
    
    @Published var apiSource: APISource {
        didSet {
            UserDefaults.standard.set(apiSource.rawValue, forKey: "apiSource")
            fetchBTCPrice()
        }
    }

    @Published var selectedCurrency: String {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }
    
    var displayInSats: Bool = false {
        didSet {
            updateSymbols()
        }
    }
    
    init(selectedCurrency: String, apiSourceRawValue: String) {
        self.selectedCurrency = selectedCurrency
        self.apiSource = APISource(rawValue: apiSourceRawValue) ?? .coinbase
        self.displayInSats = UserDefaults.standard.bool(forKey: "displayInSats")
    }

    func updateAPISource(to newSource: String) {
        if let source = APISource(rawValue: newSource) {
            apiSource = source
        }
    }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    let btcFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    let satsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    func getCurrencySymbol() -> String {
        let locales = Locale.availableIdentifiers.map { Locale(identifier: $0) }
        for locale in locales {
            if locale.currency?.identifier == selectedCurrency,
               let symbol = locale.currencySymbol,
               symbol.rangeOfCharacter(from: .letters) == nil {
                return symbol
            }
        }
        // Fallback to currency code if symbol contains letters (e.g., "US$")
        return currencySymbolFromMap[selectedCurrency] ?? selectedCurrency
    }

    private var currencySymbolFromMap: [String: String] {
        [
            "USD": "$",
            "EUR": "€",
            "GBP": "£",
            "JPY": "¥",
            "INR": "₹",
            "CNY": "¥",
            "RUB": "₽",
            "KRW": "₩",
            "NGN": "₦",
            "TRY": "₺",
            "BTC": "₿"
        ]
    }
    
    var cacheKey: String {
        "btc_price_\(selectedCurrency.lowercased())"
    }

    var cacheDateKey: String {
        "btc_price_date_\(selectedCurrency.lowercased())"
    }
    
    func updateSymbols() {
        //let currencySymbol = getCurrencySymbol()
        let currencySymbol = selectedCurrency
        switch conversionMode {
        case .fiatToBTC:
            topSymbol = currencySymbol
            bottomSymbol = displayInSats ? "sats" : "BTC"
        case .BTCToFiat:
            topSymbol = displayInSats ? "sats" : "BTC"
            bottomSymbol = currencySymbol
        }
    }
    
    func swapDirection() {
        // Toggle the conversion mode
        conversionMode = (conversionMode == .fiatToBTC) ? .BTCToFiat : .fiatToBTC
        
        // Swap the values
        let temp = topAmount
        topAmount = bottomAmount
        bottomAmount = temp
        
        // Update symbols
        updateSymbols()
    }
    
    func calculateBottomFromTop() {
        guard let btcPrice = btcPrice, let input = Double(topAmount), input > 0 else {
            bottomAmount = ""
            return
        }

        switch conversionMode {
        case .fiatToBTC:
            // Convert Fiat to BTC/Sats
            let btc = input / btcPrice
            if displayInSats {
                let sats = btc * 100_000_000
                bottomAmount = satsFormatter.string(from: NSNumber(value: sats)) ?? ""
            } else {
                bottomAmount = btcFormatter.string(from: NSNumber(value: btc)) ?? ""
            }
            
        case .BTCToFiat:
            // Convert BTC/Sats to Fiat
            if displayInSats {
                let fiat = (input / 100_000_000) * btcPrice
                bottomAmount = numberFormatter.string(from: NSNumber(value: fiat)) ?? ""
            } else {
                let fiat = input * btcPrice
                bottomAmount = numberFormatter.string(from: NSNumber(value: fiat)) ?? ""
            }
        }
    }
    
    func calculateTopFromBottom() {
        guard let btcPrice = btcPrice, let input = Double(bottomAmount), input > 0 else {
            topAmount = ""
            return
        }

        switch conversionMode {
        case .fiatToBTC:
            // Convert BTC/Sats to Fiat
            if displayInSats {
                let btc = input / 100_000_000
                let fiat = btc * btcPrice
                topAmount = numberFormatter.string(from: NSNumber(value: fiat)) ?? ""
            } else {
                let fiat = input * btcPrice
                topAmount = numberFormatter.string(from: NSNumber(value: fiat)) ?? ""
            }
            
        case .BTCToFiat:
            // Convert Fiat to BTC/Sats
            let btc = input / btcPrice
            if displayInSats {
                let sats = btc * 100_000_000
                topAmount = satsFormatter.string(from: NSNumber(value: sats)) ?? ""
            } else {
                topAmount = btcFormatter.string(from: NSNumber(value: btc)) ?? ""
            }
        }
    }

    func fetchBTCPrice() {
        switch apiSource {
        case .coinbase:
            fetchFromCoinbase()
        case .coingecko:
            fetchFromCoinGecko()
        }
    }

    private func fetchFromCoinbase() {
        let urlString = "https://api.coinbase.com/v2/prices/BTC-\(selectedCurrency)/spot"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(CoinbaseResponse.self, from: data)
                DispatchQueue.main.async {
                    self.btcPrice = Double(decoded.data.amount)
                    self.lastUpdated = Date()
                }
            } catch {
                print("Failed to fetch BTC price from Coinbase: \(error)")
            }
        }
    }

    private func fetchFromCoinGecko() {
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=\(selectedCurrency.lowercased())"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(CoinGeckoResponse.self, from: data)
                DispatchQueue.main.async {
                    self.btcPrice = decoded.bitcoin[self.selectedCurrency.lowercased()]
                    self.lastUpdated = Date()
                }
            } catch {
                print("Failed to fetch BTC price from CoinGecko: \(error)")
            }
        }
    }

    private func cachePrice(_ price: Double) {
        UserDefaults.standard.set(price, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }

    func loadCachedPrice() {
        let cached = UserDefaults.standard.double(forKey: cacheKey)
        if cached > 0 {
            btcPrice = cached
        }
        if let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date {
            lastUpdated = date
        }
    }

    func detectRegionCurrency() {
        if let regionCurrency = Locale.current.currencyCode?.uppercased(), [
            "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN",
            "BRL", "ZAR", "SGD", "HKD", "KRW", "SEK", "NOK", "NZD", "RUB", "TRY"
        ].contains(regionCurrency) {
            selectedCurrency = regionCurrency
        }
    }
}
