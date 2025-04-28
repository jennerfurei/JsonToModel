 import Foundation

struct KotlinModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useDataClass: Bool
        let useSerializable: Bool
        let packageName: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Kotlin generator")
        }
        
        let parameters = Parameters(
            useDataClass: params["useDataClass"] as? Bool ?? true,
            useSerializable: params["useSerializable"] as? Bool ?? true,
            packageName: params["packageName"] as? String ?? "com.example.model"
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
        
        let sortedKeys = jsonDict.keys.sorted()
        var orderedDict = [(key: String, value: Any)]()
        for key in sortedKeys {
            orderedDict.append((key, jsonDict[key]!))
        }
        
        let allModels = generateKotlinNestedModels(
            from: orderedDict,
            modelName: modelName,
            parameters: parameters
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateKotlinNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        parameters: Parameters
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        
        for (key, value) in jsonDict {
            if let nestedDict = value as? [String: Any] {
                let sortedNestedKeys = nestedDict.keys.sorted()
                var orderedNestedDict = [(key: String, value: Any)]()
                for nestedKey in sortedNestedKeys {
                    orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                }
                
                let nestedModelName = key.uppercasedFirstLetter()
                models += generateKotlinNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    parameters: parameters
                )
                properties.append(generateKotlinProperty(for: key, value: nestedDict))
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                let firstElement = arrayValue[0]
                
                if let nestedDict = firstElement as? [String: Any] {
                    let sortedNestedKeys = nestedDict.keys.sorted()
                    var orderedNestedDict = [(key: String, value: Any)]()
                    for nestedKey in sortedNestedKeys {
                        orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                    }
                    
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generateKotlinNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        parameters: parameters
                    )
                    properties.append(generateKotlinProperty(for: key, value: arrayValue))
                } else {
                    properties.append(generateKotlinProperty(for: key, value: arrayValue))
                }
            } else {
                properties.append(generateKotlinProperty(for: key, value: value))
            }
        }
        
        let imports = generateKotlinImports(parameters: parameters)
        let annotations = generateKotlinAnnotations(parameters: parameters)
        let propertiesStr = properties.joined(separator: "\n")
        
        let model = """
        package \(parameters.packageName)
        
        \(imports)
        
        \(annotations)
        class \(modelName) {
        \(propertiesStr)
        }
        """
        
        return [model] + models
    }
    
    private static func generateKotlinProperty(for key: String, value: Any) -> String {
        let kotlinKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determineKotlinType(from: value)
        return "    var \(kotlinKey): \(typeInfo.type)? = null"
    }
    
    private static func generateKotlinImports(parameters: Parameters) -> String {
        var imports = [String]()
        if parameters.useSerializable {
            imports.append("import java.io.Serializable")
        }
        return imports.joined(separator: "\n")
    }
    
    private static func generateKotlinAnnotations(parameters: Parameters) -> String {
        var annotations = [String]()
        if parameters.useDataClass {
            annotations.append("@data")
        }
        if parameters.useSerializable {
            annotations.append(": Serializable")
        }
        return annotations.joined(separator: "\n")
    }
}