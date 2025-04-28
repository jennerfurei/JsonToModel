 import Foundation

struct TypeScriptModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useInterface: Bool
        let useClass: Bool
        let useExport: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for TypeScript generator")
        }
        
        let parameters = Parameters(
            useInterface: params["useInterface"] as? Bool ?? true,
            useClass: params["useClass"] as? Bool ?? false,
            useExport: params["useExport"] as? Bool ?? true
        )
        
        return try generateTypeScriptModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["TypeScript"]
    }
    
    private static func generateTypeScriptModel(
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
        
        let allModels = generateTypeScriptNestedModels(
            from: orderedDict,
            modelName: modelName,
            useInterface: parameters.useInterface,
            useClass: parameters.useClass,
            useExport: parameters.useExport
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateTypeScriptNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        useInterface: Bool,
        useClass: Bool,
        useExport: Bool
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        
        for (key, value) in jsonDict {
            if let nestedDict = value as? [String: Any] {
                // 对嵌套字典也进行排序
                let sortedNestedKeys = nestedDict.keys.sorted()
                var orderedNestedDict = [(key: String, value: Any)]()
                for nestedKey in sortedNestedKeys {
                    orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                }
                
                let nestedModelName = key.uppercasedFirstLetter()
                models += generateTypeScriptNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    useInterface: useInterface,
                    useClass: useClass,
                    useExport: useExport
                )
                properties.append(generateProperty(for: key, value: nestedDict))
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
                    models += generateTypeScriptNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        useInterface: useInterface,
                        useClass: useClass,
                        useExport: useExport
                    )
                    properties.append(generateProperty(for: key, value: arrayValue))
                } else {
                    properties.append(generateProperty(for: key, value: arrayValue))
                }
            } else {
                properties.append(generateProperty(for: key, value: value))
            }
        }
        
        let declarations = properties.joined(separator: "\n")
        let exportKeyword = useExport ? "export " : ""
        
        if useInterface {
            let model = """
            \(exportKeyword)interface \(modelName) {
            \(declarations)
            }
            """
            return [model] + models
        } else if useClass {
            let model = """
            \(exportKeyword)class \(modelName) {
            \(declarations)
            }
            """
            return [model] + models
        } else {
            let model = """
            \(exportKeyword)type \(modelName) = {
            \(declarations)
            }
            """
            return [model] + models
        }
    }
    
    private static func generateProperty(for key: String, value: Any) -> String {
        let tsKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determineTypeScriptType(from: value)
        return "    \(tsKey): \(typeInfo.type);"
    }
}