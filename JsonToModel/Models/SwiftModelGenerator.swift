//
//  SwiftModelGenerator.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

struct SwiftModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let isStruct: Bool
        let useVar: Bool
        let generateInit: Bool
        let inheritance: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Swift generator")
        }
        
        let parameters = Parameters(
            isStruct: params["isStruct"] as? Bool ?? true,
            useVar: params["useVar"] as? Bool ?? true,
            generateInit: params["generateInit"] as? Bool ?? true,
            inheritance: params["inheritance"] as? String ?? ""
        )
        
        return try generateSwiftModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Swift"]
    }
    
    private static func generateSwiftModel(
        from json: String,
        modelName: String,
        parameters: Parameters
    ) throws -> String {
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelGenerationError(type: .emptyInput)
        }
        
        guard !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelGenerationError(type: .invalidModelName)
        }
        
        guard let jsonObject = try? safeParseJSON(json),
              let jsonDict = jsonObject as? [String: Any] else {
            throw ModelGenerationError(type: .invalidJSON)
        }
        
        // 按原始JSON中的字段顺序排序
        let sortedKeys = jsonDict.keys.sorted()
        var orderedDict = [(key: String, value: Any)]()
        for key in sortedKeys {
            orderedDict.append((key, jsonDict[key]!))
        }
        
        let allModels = generateSwiftNestedModels(
            from: orderedDict,
            modelName: modelName,
            isStruct: parameters.isStruct,
            useVar: parameters.useVar,
            inheritance: parameters.inheritance,
            generateInit: parameters.generateInit
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateSwiftNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        isStruct: Bool,
        useVar: Bool,
        inheritance: String,
        generateInit: Bool
    ) -> [String] {
        var models = [String]()
        var properties = [(declaration: String, initParam: String)]()
        
        for (key, value) in jsonDict {
            if let nestedDict = value as? [String: Any] {
                // 对嵌套字典也进行排序
                let sortedNestedKeys = nestedDict.keys.sorted()
                var orderedNestedDict = [(key: String, value: Any)]()
                for nestedKey in sortedNestedKeys {
                    orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                }
                
                let nestedModelName = key.uppercasedFirstLetter()
                models += generateSwiftNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    isStruct: isStruct,
                    useVar: useVar,
                    inheritance: isStruct ? "" : ": NSObject",
                    generateInit: generateInit
                )
                properties.append(generateProperty(for: key, value: nestedDict, useVar: useVar))
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                let firstElement = arrayValue[0]
                
                if let nestedDict = firstElement as? [String: Any] {
                    // 对数组中的嵌套字典也进行排序
                    let sortedNestedKeys = nestedDict.keys.sorted()
                    var orderedNestedDict = [(key: String, value: Any)]()
                    for nestedKey in sortedNestedKeys {
                        orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                    }
                    
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generateSwiftNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        isStruct: isStruct,
                        useVar: useVar,
                        inheritance: isStruct ? "" : ": NSObject",
                        generateInit: generateInit
                    )
                    properties.append(generateProperty(for: key, value: arrayValue, useVar: useVar))
                } else {
                    properties.append(generateProperty(for: key, value: arrayValue, useVar: useVar))
                }
            } else {
                properties.append(generateProperty(for: key, value: value, useVar: useVar))
            }
        }
        
        let declarations = properties.map { $0.declaration }.joined(separator: "\n")
        
        var initMethod = ""
        if generateInit {
            let params = properties.map { $0.initParam }.joined(separator: ", ")
            initMethod = """
            
                init(\(params)) {
            \(properties.map { "        self.\($0.initParam.components(separatedBy: ":")[0]) = \($0.initParam.components(separatedBy: ":")[0])" }.joined(separator: "\n"))
                }
            """
        }
        
        let keyword = isStruct ? "struct" : "class"
        let model = """
        \(keyword) \(modelName)\(inheritance) {
        \(declarations)\(initMethod)
        }
        """
        
        return [model] + models
    }
    
    private static func generateProperty(for key: String, value: Any, useVar: Bool) -> (declaration: String, initParam: String) {
        let swiftKey = key.lowercasedFirstLetter()
        let varOrLet = useVar ? "var" : "let"
        let typeInfo = TypeUtilities.determineSwiftType(from: value)
        
        let declaration = "    \(varOrLet) \(swiftKey): \(typeInfo.type)"
        let initParam = "\(swiftKey): \(typeInfo.initType)"
        
        return (declaration, initParam)
    }
}
