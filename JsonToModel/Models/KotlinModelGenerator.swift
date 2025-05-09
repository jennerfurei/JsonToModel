import Foundation

struct KotlinModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useDataClass: Bool
        let useSerializable: Bool
        let packageName: String
        let makeFieldsNullable: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Kotlin generator")
        }
        
        let parameters = Parameters(
            useDataClass: params["useDataClass"] as? Bool ?? true,
            useSerializable: params["useSerializable"] as? Bool ?? true,
            packageName: params["packageName"] as? String ?? "com.example.model",
            makeFieldsNullable: params["makeFieldsNullable"] as? Bool ?? true
        )
        
        return try generateKotlinModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Kotlin"]
    }
    
    private static func generateKotlinModel(
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
        
        let allModels = generateKotlinNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateKotlinNestedModels(
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
            
            let (property, nestedModels) = generateKotlinPropertyAndModels(
                for: key,
                value: value,
                modelName: modelName,
                parameters: parameters
            )
            
            properties.append(property)
            models += nestedModels
        }
        
        let imports = generateKotlinImports(parameters: parameters)
        let annotations = generateKotlinAnnotations(parameters: parameters)
        let propertiesStr = properties.joined(separator: ",\n    ")
        
        let model: String
        if parameters.useDataClass {
            model = """
            package \(parameters.packageName)
            
            \(imports)
            
            data class \(modelName)(
                \(propertiesStr)
            )\(annotations)
            """
        } else {
            model = """
            package \(parameters.packageName)
            
            \(imports)
            
            class \(modelName)\(annotations) {
                \(properties.map { $0.replacingOccurrences(of: "    ", with: "        ") }.joined(separator: "\n\n"))
            }
            """
        }
        
        return [model] + models
    }
    
    private static func generateKotlinPropertyAndModels(
        for key: String,
        value: Any,
        modelName: String,
        parameters: Parameters
    ) -> (property: String, models: [String]) {
        let kotlinKey = key.lowercasedFirstLetter()
        let (typeString, nestedModels) = getKotlinTypeInfo(
            for: value,
            key: key,
            modelName: modelName,
            parameters: parameters
        )
        
        let nullableMark = parameters.makeFieldsNullable ? "?" : ""
        let defaultValue = parameters.makeFieldsNullable ? " = null" : ""
        let property: String
        
        if parameters.useDataClass {
            property = "    val \(kotlinKey): \(typeString)\(nullableMark)\(defaultValue)"
        } else {
            property = "    var \(kotlinKey): \(typeString)\(nullableMark)\(defaultValue)"
        }
        
        return (property, nestedModels)
    }
    
    private static func getKotlinTypeInfo(
        for value: Any,
        key: String,
        modelName: String,
        parameters: Parameters
    ) -> (typeString: String, models: [String]) {
        var models = [String]()
        var typeStr = "Any"
        
        switch value {
        case is String:
            typeStr = "String"
            
        case is Int, is Bool:
            let numberValue = value as? NSNumber
            if numberValue != nil && isBoolean(numberValue!) {
                typeStr = "Boolean"
            } else {
                typeStr = "Int"
            }
          
        case is Double, is Float:
            typeStr = "Double"
            
        case let dict as [String: Any]:
            let nestedModelName = key.uppercasedFirstLetter()
            models += generateKotlinNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters,
                isArrayItem: true
            )
            typeStr = nestedModelName
        case let array as [Any]:
            if let first = array.first {
                let (elementType, nested) = getKotlinTypeInfo(
                    for: first,
                    key: key,
                    modelName: modelName,
                    parameters: parameters
                )
                models += nested
                typeStr = "List<\(elementType)>"
            } else {
                typeStr = "List<Any>"
            }
        case is NSNull:
            typeStr = "Any"
        default:
            typeStr = "Any"
        }
        
        return (typeStr, models)
    }
    
    private static func generateKotlinImports(parameters: Parameters) -> String {
        var imports = [String]()
        if parameters.useSerializable {
            imports.append("import java.io.Serializable")
        }
        return imports.isEmpty ? "" : imports.joined(separator: "\n")
    }
    
    private static func generateKotlinAnnotations(parameters: Parameters) -> String {
        var annotations = [String]()
        if parameters.useSerializable {
            annotations.append(" : Serializable")
        }
        return annotations.joined(separator: " ")
    }
}
