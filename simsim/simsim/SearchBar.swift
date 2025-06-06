//
//  SearchBar.swift
//  simsim
//
//  Created by Sri Ujjwal Reddy B on 6/5/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search your photos..."
    @Namespace private var animation
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.subtleText)
                .font(.system(size: 16, weight: .medium))
                .animation(.spring(), value: text.isEmpty)
                .accessibilityLabel("Search")
            
            TextField(placeholder, text: $text)
                .padding(.vertical, 10)
                .foregroundColor(.lightText)
                .accentColor(.accentTeal)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
                .accessibilityIdentifier("photoSearchField")
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                    }
                    isSearchFocused = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.subtleText)
                        .font(.system(size: 16))
                        .padding(2)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
        }
    }
}

#Preview {
    ZStack {
        Color.darkBackground.edgesIgnoringSafeArea(.all)
        SearchBar(text: .constant("Test Search"))
    }
    .previewLayout(.sizeThatFits)
}
