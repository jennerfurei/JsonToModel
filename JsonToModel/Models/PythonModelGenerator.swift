 import Foundation

struct PythonModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useDataclass: Bool
        let useTypeHints: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Python generator")
        }
        
        let parameters = Parameters(
            useDataclass: params["useDataclass"] as? Bool ?? true,
            useTypeHints: params["useTypeHints"] as? Bool ?? true
        )
        
        return try generatePythonModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Python"]
    }
    
    private static func generatePythonModel(
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
        
        let allModels = generatePythonNestedModels(
            from: orderedDict,
            modelName: modelName,
            useDataclass: parameters.useDataclass,
            useTypeHints: parameters.useTypeHints
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generatePythonNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        useDataclass: Bool,
        useTypeHints: Bool
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
                models += generatePythonNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    useDataclass: useDataclass,
                    useTypeHints: useTypeHints
                )
                properties.append(generateProperty(for: key, value: nestedDict, useTypeHints: useTypeHints))
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
                    models += generatePythonNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        useDataclass: useDataclass,
                        useTypeHints: useTypeHints
                    )
                    properties.append(generateProperty(for: key, value: arrayValue, useTypeHints: useTypeHints))
                } else {
                    properties.append(generateProperty(for: key, value: arrayValue, useTypeHints: useTypeHints))
                }
            } else {
                properties.append(generateProperty(for: key, value: value, useTypeHints: useTypeHints))
            }
        }
        
        let declarations = properties.joined(separator: "\n")
        
        let decorator = useDataclass ? "@dataclass\n" : ""
        let model = """
        \(decorator)class \(modelName):
        \(declarations)
        """
        
        return [model] + models
    }
    
    private static func generateProperty(for key: String, value: Any, useTypeHints: Bool) -> String {
        let pythonKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determinePythonType(from: value)
        
        if useTypeHints {
            return "    \(pythonKey): \(typeInfo.type)"
        } else {
            return "    \(pythonKey)"
        }
    }
}