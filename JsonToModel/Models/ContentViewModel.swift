//
//  ContentViewModel.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import SwiftUI
import Combine

class ContentViewModel: ObservableObject {
    // MARK: - Basic Properties
    @Published var jsonInput: String = ""
    @Published var modelOutput: String = ""
    @Published var modelName: String = ""
    @Published var inheritanceInput: String = ""
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var selectedLanguage: OutputLanguage = .swift
    
    // MARK: - Swift Options
    @Published var isStructSelected: Bool = true
    @Published var useVarInsteadOfLet: Bool = true
    @Published var generateInit: Bool = true
    
    // MARK: - Python Options
    @Published var useDataclass: Bool = true
    @Published var useTypeHints: Bool = true
    
    // MARK: - TypeScript Options
    @Published var useInterface: Bool = true
    @Published var useClass: Bool = false
    @Published var useExport: Bool = true
    
    // MARK: - Java Options
    @Published var useLombok: Bool = true
    @Published var useGettersSetters: Bool = false
    @Published var useSerializable: Bool = true
    @Published var javaPackageName: String = "com.example.model"
    
    // MARK: - Kotlin Options
    @Published var useDataClass: Bool = true
    @Published var kotlinPackageName: String = "com.example.model"
    
    // MARK: - PHP Options
//    @Published var useGettersSetters: Bool = true
    @Published var phpNamespace: String = "App\\Models"
    
    // MARK: - C++ Options
    @Published var cppNamespace: String = "model"
    
    // MARK: - Ruby Options
    @Published var useAttr_accessor: Bool = true
    @Published var rubyModuleName: String = "Model"
    
    // MARK: - Rust Options
    @Published var useSerde: Bool = true
    @Published var useClone: Bool = true
    @Published var useDebug: Bool = true
    
    // MARK: - Generators
    private var generators: [OutputLanguage: ModelGeneratorProtocol.Type] = [
        .swift: SwiftModelGenerator.self,
        .objectiveC: ObjCModelGenerator.self,
        .python: PythonModelGenerator.self,
        .typescript: TypeScriptModelGenerator.self,
        .java: JavaModelGenerator.self,
        .kotlin: KotlinModelGenerator.self,
        .php: PHPModelGenerator.self,
        .cpp: CPPModelGenerator.self,
        .ruby: RubyModelGenerator.self,
        .rust: RustModelGenerator.self
    ]
    
    // MARK: - Public Methods
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
    
    // MARK: - Private Methods
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
            
        case .python:
            params["useDataclass"] = useDataclass
            params["useTypeHints"] = useTypeHints
            
        case .typescript:
            params["useInterface"] = useInterface
            params["useClass"] = useClass
            params["useExport"] = useExport
            
        case .java:
            params["useLombok"] = useLombok
            params["useGettersSetters"] = useGettersSetters
            params["useSerializable"] = useSerializable
            params["packageName"] = javaPackageName
            
        case .kotlin:
            params["useDataClass"] = useDataClass
            params["useSerializable"] = useSerializable
            params["packageName"] = kotlinPackageName
            
        case .php:
            params["useGettersSetters"] = useGettersSetters
            params["namespace"] = phpNamespace
            
        case .cpp:
            params["useGettersSetters"] = useGettersSetters
            params["namespace"] = cppNamespace
            
        case .ruby:
            params["useAttr_accessor"] = useAttr_accessor
            params["moduleName"] = rubyModuleName
            
        case .rust:
            params["useSerde"] = useSerde
            params["useClone"] = useClone
            params["useDebug"] = useDebug
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
    case python = "Python"
    case typescript = "TypeScript"
    case java = "Java"
    case kotlin = "Kotlin"
    case php = "PHP"
    case cpp = "C++"
    case ruby = "Ruby"
    case rust = "Rust"
}
