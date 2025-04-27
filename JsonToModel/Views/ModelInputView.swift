//
//  ModelInputView.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI

struct ModelInputView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("JSON Input:")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            ScrollView {
                TextEditor(text: $viewModel.jsonInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150, maxHeight: .infinity)
                    .padding(4)
            }
            .frame(height: 300)
            .border(Color.gray, width: 1)
            .cornerRadius(5)
        }
    }
}
