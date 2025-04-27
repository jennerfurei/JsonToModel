//
//  ContentView.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView(viewModel: viewModel)
            
            HStack {
                
                ModelInputView(viewModel: viewModel)
                
                ModelOutputView(viewModel: viewModel)
            }

            GenerateButton(viewModel: viewModel)

        }
        .padding()
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
