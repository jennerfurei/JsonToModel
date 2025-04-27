//
//  GenerateButton.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI

struct GenerateButton: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        Button(action: {
            viewModel.generateModel()
        }) {
            HStack {
                Image(systemName: "hammer.fill")
                Text("Generate \(viewModel.selectedLanguage.rawValue) Model")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(Color.blue)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .padding(.vertical)
        .disabled(viewModel.jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                 viewModel.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity((viewModel.jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  viewModel.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
    }
}

struct GenerateButton_Previews: PreviewProvider {
    static var previews: some View {
        GenerateButton(viewModel: ContentViewModel())
    }
}
