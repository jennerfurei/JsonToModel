//
//  ModelOutputView.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI

struct ModelOutputView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(viewModel.selectedLanguage.rawValue) Model:")
                    .font(.headline)
                Spacer()
                
                Button(action: viewModel.copyToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            
            ScrollView {
                TextEditor(text: $viewModel.modelOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150, maxHeight: .infinity)
                    .padding(4)
                    .disabled(true)
            }
            .frame(height: 300)
            .border(Color.gray, width: 1)
            .cornerRadius(5)
        }
    }
}
