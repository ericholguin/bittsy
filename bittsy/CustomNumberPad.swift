//
//  CustomNumberPad.swift
//  bittsy
//
//  Created by eric on 4/7/25.
//


import SwiftUI

struct CustomNumberPad: View {
    var onNumberTap: (String) -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                NumberButton(value: "1", onTap: onNumberTap)
                NumberButton(value: "2", onTap: onNumberTap)
                NumberButton(value: "3", onTap: onNumberTap)
            }
            HStack(spacing: 8) {
                NumberButton(value: "4", onTap: onNumberTap)
                NumberButton(value: "5", onTap: onNumberTap)
                NumberButton(value: "6", onTap: onNumberTap)
            }
            HStack(spacing: 8) {
                NumberButton(value: "7", onTap: onNumberTap)
                NumberButton(value: "8", onTap: onNumberTap)
                NumberButton(value: "9", onTap: onNumberTap)
            }
            HStack(spacing: 8) {
                NumberButton(value: ".", onTap: onNumberTap)
                NumberButton(value: "0", onTap: onNumberTap)
                Button(action: onDelete) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 28))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 75)
                        .background(Color(.systemGray5))
                        .cornerRadius(9999)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
    }
}

struct NumberButton: View {
    let value: String
    let onTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            onTap(value)
        }) {
            Text(value)
                .font(.system(size: 32, weight: .medium))
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 75)
                .background(Color(.systemGray5))
                .cornerRadius(9999)
                .foregroundColor(.primary)
        }
    }
}

struct CustomNumberPad_Previews: PreviewProvider {
    static var previews: some View {
        CustomNumberPad(onNumberTap: {_ in}, onDelete: {})
    }
}
