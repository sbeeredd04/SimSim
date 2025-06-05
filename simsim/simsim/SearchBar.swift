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

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.subtleText)
            TextField(placeholder, text: $text)
                .padding(.vertical, 8)
                .foregroundColor(.lightText)
                .accentColor(.accentTeal)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        Color.darkBackground.edgesIgnoringSafeArea(.all)
        SearchBar(text: .constant("Test Search"))
    }
    .previewLayout(.sizeThatFits)
}
