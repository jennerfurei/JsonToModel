 import Foundation

struct PHPModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useGettersSetters: Bool
        let namespace: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for PHP generator")
        }
        
        let parameters = Parameters(
            useGettersSetters: params["useGettersSetters"] as? Bool ?? true,
            namespace: params["namespace"] as? String ?? "App\\Models"
        )
        
        return try generatePHPModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["PHP"]
    }
    
    private static func generatePHPModel(
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
        
        let allModels = generatePHPNestedModels(
            from: orderedDict,
            modelName: modelName,
            parameters: parameters
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generatePHPNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        parameters: Parameters
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        var gettersSetters = [String]()
        
        for (key, value) in jsonDict {
            if let nestedDict = value as? [String: Any] {
                let sortedNestedKeys = nestedDict.keys.sorted()
                var orderedNestedDict = [(key: String, value: Any)]()
                for nestedKey in sortedNestedKeys {
                    orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                }
                
                let nestedModelName = key.uppercasedFirstLetter()
                models += generatePHPNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    parameters: parameters
                )
                
                let (property, getterSetter) = generatePHPProperty(
                    for: key,
                    value: nestedDict,
                    useGettersSetters: parameters.useGettersSetters
                )
                properties.append(property)
                if parameters.useGettersSetters {
                    gettersSetters.append(getterSetter)
                }
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                let firstElement = arrayValue[0]
                
                if let nestedDict = firstElement as? [String: Any] {
                    let sortedNestedKeys = nestedDict.keys.sorted()
                    var orderedNestedDict = [(key: String, value: Any)]()
                    for nestedKey in sortedNestedKeys {
                        orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                    }
                    
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generatePHPNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        parameters: parameters
                    )
                    
                    let (property, getterSetter) = generatePHPProperty(
                        for: key,
                        value: arrayValue,
                        useGettersSetters: parameters.useGettersSetters
                    )
                    properties.append(property)
                    if parameters.useGettersSetters {
                        gettersSetters.append(getterSetter)
                    }
                } else {
                    let (property, getterSetter) = generatePHPProperty(
                        for: key,
                        value: arrayValue,
                        useGettersSetters: parameters.useGettersSetters
                    )
                    properties.append(property)
                    if parameters.useGettersSetters {
                        gettersSetters.append(getterSetter)
                    }
                }
            } else {
                let (property, getterSetter) = generatePHPProperty(
                    for: key,
                    value: value,
                    useGettersSetters: parameters.useGettersSetters
                )
                properties.append(property)
                if parameters.useGettersSetters {
                    gettersSetters.append(getterSetter)
                }
            }
        }
        
        let propertiesStr = properties.joined(separator: "\n")
        let gettersSettersStr = gettersSetters.joined(separator: "\n\n")
        
        let model = """
        <?php
        
        namespace \(parameters.namespace);
        
        class \(modelName)
        {
        \(propertiesStr)
        
        \(gettersSettersStr)
        }
        """
        
        return [model] + models
    }
    
    private static func generatePHPProperty(
        for key: String,
        value: Any,
        useGettersSetters: Bool
    ) -> (property: String, getterSetter: String) {
        let phpKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determinePHPType(from: value)
        
        let property = "    private \(typeInfo.type) $\(phpKey);"
        
        var getterSetter = ""
        if useGettersSetters {
            let capitalizedKey = key.uppercasedFirstLetter()
            getterSetter = """
                public function get\(capitalizedKey)(): \(typeInfo.type)
                {
                    return $this->\(phpKey);
                }
                
                public function set\(capitalizedKey)(\(typeInfo.type) $\(phpKey)): void
                {
                    $this->\(phpKey) = $\(phpKey);
                }
            """
        }
        
        return (property, getterSetter)
    }
}