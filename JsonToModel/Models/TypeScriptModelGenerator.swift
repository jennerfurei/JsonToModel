import Foundation

struct TypeScriptModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useInterface: Bool
        let useType: Bool
        let useExport: Bool
        let makeFieldsOptional: Bool
        let useStrictTypes: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for TypeScript generator")
        }
        
        let parameters = Parameters(
            useInterface: params["useInterface"] as? Bool ?? true,
            useType: params["useType"] as? Bool ?? false,
            useExport: params["useExport"] as? Bool ?? true,
            makeFieldsOptional: params["makeFieldsOptional"] as? Bool ?? false,
            useStrictTypes: params["useStrictTypes"] as? Bool ?? true
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
        
        let allModels = generateTypeScriptNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        // 添加文件头注释和导入语句
        let header = """
        // Auto-generated TypeScript model
        // Generated from JSON on \(Date())
        
        """
        
        return header + allModels.joined(separator: "\n\n")
    }
    
    private static func generateTypeScriptNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        isArrayItem: Bool = false
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        
        let sortedKeys = jsonDict.keys.sorted()
        
        for key in sortedKeys {
            guard let value = jsonDict[key] else { continue }
            
            let tsKey = key.lowercasedFirstLetter()
            let (typeString, nestedModels) = getTypeInfo(
                for: value,
                key: key,
                modelName: modelName,
                parameters: parameters
            )
            
            models += nestedModels
            
            let isOptional = parameters.makeFieldsOptional || value is NSNull
            let optionalMark = isOptional ? "?" : ""
            let propertyLine = "    \(tsKey)\(optionalMark): \(typeString);"
            
            properties.append(propertyLine)
        }
        
        let exportKeyword = parameters.useExport ? "export " : ""
        let modelDef: String
        
        if parameters.useInterface {
            modelDef = """
            \(exportKeyword)interface \(modelName) {
            \(properties.joined(separator: "\n"))
            }
            """
        } else if parameters.useType {
            modelDef = """
            \(exportKeyword)type \(modelName) = {
            \(properties.joined(separator: "\n"))
            }
            """
        } else {
            modelDef = """
            \(exportKeyword)class \(modelName) {
            \(properties.joined(separator: "\n"))
            }
            """
        }
        
        return [modelDef] + models
    }
    
    private static func getTypeInfo(
        for value: Any,
        key: String,
        modelName: String,
        parameters: Parameters
    ) -> (typeString: String, models: [String]) {
        var models = [String]()
        var typeStr = "any"
        
        switch value {
        case is String:
            typeStr = parameters.useStrictTypes ? "string" : "string"
        case is Int, is Double, is Float, is Bool:
            let numberValue = value as? NSNumber
            if numberValue != nil && isBoolean(numberValue!) {
                typeStr = parameters.useStrictTypes ? "boolean" : "boolean"
            } else {
                typeStr = parameters.useStrictTypes ? "number" : "number"
            }

        case let dict as [String: Any]:
            let nestedModelName = key.uppercasedFirstLetter()
            models += generateTypeScriptNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters,
                isArrayItem: true
            )
            typeStr = nestedModelName
        case let array as [Any]:
            if let first = array.first {
                let (elementType, nested) = getTypeInfo(
                    for: first,
                    key: key,
                    modelName: modelName,
                    parameters: parameters
                )
                models += nested
                typeStr = "\(elementType)[]"
            } else {
                typeStr = "any[]"
            }
        case is NSNull:
            typeStr = "any"
        default:
            typeStr = "any"
        }
        
        return (typeStr, models)
    }
}
