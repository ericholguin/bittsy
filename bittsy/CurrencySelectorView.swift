//
//  CurrencySelectorView.swift
//  bittsy
//
//  Created by eric on 4/6/25.
//

import SwiftUI

struct CurrencySelectorView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    
    // List of supported currencies with their corresponding flag emojis
    let currencyData = [
        ("USD", "🇺🇸"), // United States
        ("EUR", "🇪🇺"), // European Union
        ("GBP", "🇬🇧"), // United Kingdom
        ("JPY", "🇯🇵"), // Japan
        ("CAD", "🇨🇦"), // Canada
        ("AUD", "🇦🇺"), // Australia
        ("CHF", "🇨🇭"), // Switzerland
        ("CNY", "🇨🇳"), // China
        ("INR", "🇮🇳"), // India
        ("MXN", "🇲🇽"), // Mexico
        ("BRL", "🇧🇷"), // Brazil
        ("ZAR", "🇿🇦"), // South Africa
        ("SGD", "🇸🇬"), // Singapore
        ("HKD", "🇭🇰"), // Hong Kong
        ("KRW", "🇰🇷"), // South Korea
        ("SEK", "🇸🇪"), // Sweden
        ("NOK", "🇳🇴"), // Norway
        ("NZD", "🇳🇿"), // New Zealand
        ("RUB", "🇷🇺"), // Russia
        ("TRY", "🇹🇷")  // Turkey
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(currencyData, id: \.0) { currency, flag in
                    Button(action: {
                        selectedCurrency = currency
                        dismiss()
                    }) {
                        HStack {
                            Text(flag)
                                .font(.system(size: 24))
                                .fontWeight(.bold)
                            Text(currency)
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                            Spacer()
                            if selectedCurrency == currency {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Currency")
        }
    }
}

struct CurrencySelectorView_Previews: PreviewProvider {
    static var previews: some View {
        CurrencySelectorView(selectedCurrency: .constant("USD"))
    }
}
