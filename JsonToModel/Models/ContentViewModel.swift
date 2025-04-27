//
//  ContentViewModel.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI
import Combine

class ContentViewModel: ObservableObject {
    @Published var jsonInput: String = ""
    @Published var modelOutput: String = ""
    @Published var modelName: String = ""
    @Published var inheritanceInput: String = ""
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    @Published var isStructSelected: Bool = true
    @Published var useVarInsteadOfLet: Bool = true
    @Published var generateInit: Bool = true
    @Published var selectedLanguage: OutputLanguage = .swift
    
    private var generators: [OutputLanguage: ModelGeneratorProtocol.Type] = [
        .swift: SwiftModelGenerator.self,
        .objectiveC: ObjCModelGenerator.self
    ]
    
    func generateModel() {
        guard !jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "Please enter JSON data")
            return
        }
        
        guard !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "Please enter a model name")
            return
        }
        
        do {
            let generator = generators[selectedLanguage]!
            let additionalParams = prepareParameters()
            
            modelOutput = try generator.generateModel(
                from: jsonInput,
                modelName: modelName,
                additionalParameters: additionalParams
            )
        } catch let error as ModelGenerationError {
            showAlert(message: error.localizedDescription)
        } catch {
            showAlert(message: "An unknown error occurred")
        }
    }
    
    func copyToClipboard() {
        guard !modelOutput.isEmpty else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(modelOutput, forType: .string)
        #else
        UIPasteboard.general.string = modelOutput
        #endif
    }
    
    private func prepareParameters() -> [String: Any] {
        var params: [String: Any] = [:]
        
        switch selectedLanguage {
        case .swift:
            params["isStruct"] = isStructSelected
            params["useVar"] = useVarInsteadOfLet
            params["generateInit"] = generateInit
            params["inheritance"] = inheritanceInput.isEmpty ?
                (isStructSelected ? "" : ": NSObject") :
                (isStructSelected ? ": \(inheritanceInput)" : ": \(inheritanceInput)")
            
        case .objectiveC:
            params["inheritance"] = inheritanceInput.isEmpty ? ": NSObject" : ": \(inheritanceInput)"
        }
        
        return params
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

enum OutputLanguage: String, CaseIterable {
    case swift = "Swift"
    case objectiveC = "Objective-C"
    
    // 可以轻松添加更多语言
    // case kotlin = "Kotlin"
    // case java = "Java"
    // case typescript = "TypeScript"
}
