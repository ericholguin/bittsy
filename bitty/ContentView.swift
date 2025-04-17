import SwiftUI
import Foundation

struct ContentView: View {
    @State private var highlightPrice = false
    @State private var showingCurrencySelector = false
    @AppStorage("displayInSats") private var displayInSats = false
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("apiSource") private var apiSourceRawValue = APISource.coinbase.rawValue
    
    @StateObject private var viewModel = ConverterViewModel(
        selectedCurrency: UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD",
        apiSourceRawValue: UserDefaults.standard.string(forKey: "apiSource") ?? APISource.coinbase.rawValue
    )

    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    
                    PriceSourcePicker(selectedSource: $viewModel.apiSource)
                    
                    HStack {
                        if let btcPrice = viewModel.btcPrice {
                            Text("\(viewModel.numberFormatter.string(from: NSNumber(value: btcPrice)) ?? "-") \(viewModel.selectedCurrency)")
                                .lineLimit(1)
                                .minimumScaleFactor(0.1)
                                .font(highlightPrice ? .title : .subheadline)
                                .fontWeight(highlightPrice ? .heavy : .bold)
                                .foregroundColor(highlightPrice ? .orange : .primary)
                                .animation(.easeInOut(duration: 0.3), value: highlightPrice)
                        } else {
                            Text("---")
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.fetchBTCPrice()
                                highlightPrice = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    highlightPrice = false
                                }
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.leading, 4)
                    }
                    
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Last updated: \(viewModel.dateFormatter.string(from: lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                VStack(spacing: 0) {
                    CurrencyTextField(
                        text: $viewModel.topAmount,
                        symbol: viewModel.topSymbol,
                        isActive: viewModel.activeField == .top,
                        onSymbolTap: {
                            if viewModel.topSymbol == "BTC" || viewModel.topSymbol == "sats" {
                                displayInSats.toggle()
                            } else {
                                showingCurrencySelector = true
                            }
                        },
                        onTextFieldTap: {
                            viewModel.activeField = .top
                        },
                        onTextChange: {
                            if viewModel.activeField == .top {
                                viewModel.calculateBottomFromTop()
                            }
                        }
                    )

                    HStack(spacing:0) {
                        Button(action: {
                            viewModel.swapDirection()
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.headline)
                                .padding(5)
                                .foregroundColor(.orange)
                        }
                        
                        VStack {
                            Divider()
                                .frame(height: 2)
                                .background(Color.gray.opacity(0.3))
                        }
                    }
                    
                    CurrencyTextField(
                        text: $viewModel.bottomAmount,
                        symbol: viewModel.bottomSymbol,
                        isActive: viewModel.activeField == .bottom,
                        onSymbolTap: {
                            if viewModel.bottomSymbol == "BTC" || viewModel.bottomSymbol == "sats" {
                                displayInSats.toggle()
                            } else {
                                showingCurrencySelector = true
                            }
                        },
                        onTextFieldTap: {
                            viewModel.activeField = .bottom
                        },
                        onTextChange: {
                            if viewModel.activeField == .bottom {
                                viewModel.calculateTopFromBottom()
                            }
                        }
                    )
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                CustomNumberPad(
                    onNumberTap: { digit in
                        appendDigit(digit)
                    },
                    onDelete: {
                        deleteDigit()
                    }
                )
                .background(Color(.systemBackground))
            }
            .sheet(isPresented: $showingCurrencySelector) {
                CurrencySelectorView(selectedCurrency: $selectedCurrency)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                viewModel.detectRegionCurrency()
                viewModel.loadCachedPrice()
                viewModel.fetchBTCPrice()
                viewModel.updateSymbols()
            }
            .onChange(of: selectedCurrency) { newValue in
                viewModel.selectedCurrency = newValue
                viewModel.fetchBTCPrice()
                viewModel.updateSymbols()
            }
            .onChange(of: displayInSats) { newValue in
                viewModel.displayInSats = newValue
                viewModel.updateSymbols()
                if viewModel.activeField == .top {
                    viewModel.calculateBottomFromTop()
                } else {
                    viewModel.calculateTopFromBottom()
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if viewModel.activeField == .top {
            if digit == "." && viewModel.topAmount.contains(".") {
                return
            }

            if digit == "." && viewModel.topAmount.isEmpty {
                viewModel.topAmount = "0."
                return
            }
            
            viewModel.topAmount += digit
            viewModel.calculateBottomFromTop()
        } else {

            if digit == "." && viewModel.bottomAmount.contains(".") {
                return
            }
            
            if digit == "." && viewModel.bottomAmount.isEmpty {
                viewModel.bottomAmount = "0."
                return
            }
            
            viewModel.bottomAmount += digit
            viewModel.calculateTopFromBottom()
        }
    }
    
    private func deleteDigit() {
        if viewModel.activeField == .top {
            guard !viewModel.topAmount.isEmpty else { return }
            viewModel.topAmount.removeLast()
            viewModel.calculateBottomFromTop()
        } else {
            guard !viewModel.bottomAmount.isEmpty else { return }
            viewModel.bottomAmount.removeLast()
            viewModel.calculateTopFromBottom()
        }
    }
}

struct PriceSourcePicker: View {
    @Binding var selectedSource: APISource

    var body: some View {
        HStack(spacing: 0) {
            Image("\(selectedSource.logoName)")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Picker("Price Source", selection: $selectedSource) {
                ForEach(APISource.allCases, id: \.self) { source in
                    Text(source.rawValue.capitalized)
                        .tag(source)
                }
            }
        }
    }
}

struct CurrencyTextField: View {
    @Binding var text: String
    let symbol: String
    let isActive: Bool
    var onSymbolTap: () -> Void
    var onTextFieldTap: () -> Void
    var onTextChange: () -> Void
    
    @State private var showCopiedMessage = false
    
    var body: some View {
        HStack(spacing: 2) {

            Text(formattedAmount(text))
                .multilineTextAlignment(.trailing)
                .font(.system(size: 70, weight: .heavy))
                .foregroundColor(isActive ? .primary : Color.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onTapGesture {
                    onTextFieldTap()
                }
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = text
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button(action: {
                        if let pastedText = UIPasteboard.general.string {
                            text = pastedText
                            onTextChange()
                        }
                    }) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            
            Button(action: onSymbolTap) {
                    Text(symbol)
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(Color.gray)
                        .minimumScaleFactor(0.1)
                        .frame(width: 55, height: 30, alignment: .bottom)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color.gray)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top)
        }
        .frame(height:100)
    }
}

func formattedAmount(_ amountString: String) -> String {
    if amountString.isEmpty {
        return "0"
    }

    if amountString == "0." {
        return "0."
    }

    if amountString.hasSuffix(".") {
        if let number = Double(amountString) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.minimumFractionDigits = 1
            numberFormatter.maximumFractionDigits = 1
            
            if let formattedNumber = numberFormatter.string(from: NSNumber(value: number)) {
                return formattedNumber
            }
        }
        return amountString
    }
    
    if amountString.contains(".") {
        if let decimalPart = amountString.split(separator: ".").last {
            let decimalDigits = decimalPart.count
            
            if let number = Double(amountString) {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                numberFormatter.minimumFractionDigits = decimalDigits
                numberFormatter.maximumFractionDigits = decimalDigits
                
                if let formattedNumber = numberFormatter.string(from: NSNumber(value: number)) {
                    return formattedNumber
                }
            }
        }
    } else {
        if let number = Double(amountString) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.minimumFractionDigits = 0
            numberFormatter.maximumFractionDigits = 0
            
            if let formattedNumber = numberFormatter.string(from: NSNumber(value: number)) {
                return formattedNumber
            }
        }
    }

    return amountString
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
