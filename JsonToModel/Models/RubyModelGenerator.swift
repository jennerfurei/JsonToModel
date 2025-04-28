 import Foundation

struct RubyModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useAttrAccessor: Bool
        let moduleName: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Ruby generator")
        }
        
        let parameters = Parameters(
            useAttrAccessor: params["useAttr_accessor"] as? Bool ?? true,
            moduleName: params["moduleName"] as? String ?? "Model"
        )
        
        return try generateRubyModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Ruby"]
    }
    
    private static func generateRubyModel(
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
        
        let allModels = generateRubyNestedModels(
            from: orderedDict,
            modelName: modelName,
            parameters: parameters
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateRubyNestedModels(
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
                models += generateRubyNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    parameters: parameters
                )
                properties.append(generateRubyProperty(for: key, value: nestedDict))
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                let firstElement = arrayValue[0]
                
                if let nestedDict = firstElement as? [String: Any] {
                    let sortedNestedKeys = nestedDict.keys.sorted()
                    var orderedNestedDict = [(key: String, value: Any)]()
                    for nestedKey in sortedNestedKeys {
                        orderedNestedDict.append((nestedKey, nestedDict[nestedKey]!))
                    }
                    
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generateRubyNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        parameters: parameters
                    )
                    properties.append(generateRubyProperty(for: key, value: arrayValue))
                } else {
                    properties.append(generateRubyProperty(for: key, value: arrayValue))
                }
            } else {
                properties.append(generateRubyProperty(for: key, value: value))
            }
        }
        
        let propertiesStr = properties.joined(separator: "\n")
        
        let model = """
        module \(parameters.moduleName)
          class \(modelName)
        \(propertiesStr)
          end
        end
        """
        
        return [model] + models
    }
    
    private static func generateRubyProperty(for key: String, value: Any) -> String {
        let rubyKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determineRubyType(from: value)
        return "    attr_accessor :\(rubyKey)"
    }
}
