 import Foundation

struct RustModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useSerde: Bool
        let useClone: Bool
        let useDebug: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Rust generator")
        }
        
        let parameters = Parameters(
            useSerde: params["useSerde"] as? Bool ?? true,
            useClone: params["useClone"] as? Bool ?? true,
            useDebug: params["useDebug"] as? Bool ?? true
        )
        
        return try generateRustModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Rust"]
    }
    
    private static func generateRustModel(
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
        
        let allModels = generateRustNestedModels(
            from: orderedDict,
            modelName: modelName,
            parameters: parameters
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateRustNestedModels(
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
                models += generateRustNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    parameters: parameters
                )
                properties.append(generateRustProperty(for: key, value: nestedDict))
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                let firstElement = arrayValue[0]
                
                if let nestedDict = firstElement as? [String: Any] {
                    let sortedNestedKeys = nestedDict.keys.sorted()
                    var orderedNestedDict = [(key: String, value: Any)]()
                    for nestedKey in sortedNestedKeys {
                        orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                    }
                    
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generateRustNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        parameters: parameters
                    )
                    properties.append(generateRustProperty(for: key, value: arrayValue))
                } else {
                    properties.append(generateRustProperty(for: key, value: arrayValue))
                }
            } else {
                properties.append(generateRustProperty(for: key, value: value))
            }
        }
        
        let propertiesStr = properties.joined(separator: "\n")
        let derives = generateRustDerives(parameters: parameters)
        
        let model = """
        \(derives)
        pub struct \(modelName) {
        \(propertiesStr)
        }
        """
        
        return [model] + models
    }
    
    private static func generateRustProperty(for key: String, value: Any) -> String {
        let rustKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determineRustType(from: value)
        return "    pub \(rustKey): \(typeInfo.type),"
    }
    
    private static func generateRustDerives(parameters: Parameters) -> String {
        var derives = ["#[derive("]
        if parameters.useSerde {
            derives.append("Serialize, Deserialize")
        }
        if parameters.useClone {
            derives.append("Clone")
        }
        if parameters.useDebug {
            derives.append("Debug")
        }
        derives.append(")]")
        return derives.joined(separator: ", ")
    }
}