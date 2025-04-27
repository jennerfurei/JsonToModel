//
//  HeaderView.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        HStack {
            Text("JSON to Model")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // 语言选择下拉框
            Picker("Language", selection: $viewModel.selectedLanguage) {
                ForEach(OutputLanguage.allCases, id: \.self) { language in
                    Text(language.rawValue).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .padding(.trailing, 8)
        }
        .padding(.bottom, 10)
        
        // 模型名称输入
        HStack {
            Text("Model Name:")
                .font(.headline)
            TextField("ModelName", text: $viewModel.modelName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
        }
        
        // Swift特有选项
        if viewModel.selectedLanguage == .swift {
            HStack {
                Picker("Type", selection: $viewModel.isStructSelected) {
                    Text("Struct").tag(true)
                    Text("Class").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Toggle("Use var", isOn: $viewModel.useVarInsteadOfLet)
                Toggle("Generate init", isOn: $viewModel.generateInit)
            }
        }
        
        // 继承/协议输入
        if !viewModel.isStructSelected || (!viewModel.inheritanceInput.isEmpty && viewModel.isStructSelected) {
            HStack {
                Text(viewModel.selectedLanguage == .swift ?
                     (viewModel.isStructSelected ? "Protocols:" : "Inheritance:") :
                     "Inheritance:")
                TextField(viewModel.selectedLanguage == .swift ?
                         (viewModel.isStructSelected ? "Codable, Equatable" : "NSObject, MyBaseClass") :
                         "NSObject, MyBaseClass",
                         text: $viewModel.inheritanceInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(viewModel: ContentViewModel())
    }
}
