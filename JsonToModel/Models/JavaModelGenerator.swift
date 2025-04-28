 import Foundation

struct JavaModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useLombok: Bool
        let useGettersSetters: Bool
        let useSerializable: Bool
        let packageName: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Java generator")
        }
        
        let parameters = Parameters(
            useLombok: params["useLombok"] as? Bool ?? true,
            useGettersSetters: params["useGettersSetters"] as? Bool ?? false,
            useSerializable: params["useSerializable"] as? Bool ?? true,
            packageName: params["packageName"] as? String ?? "com.example.model"
        )
        
        return try generateJavaModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["Java"]
    }
    
    private static func generateJavaModel(
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
        
        let allModels = generateJavaNestedModels(
            from: orderedDict,
            modelName: modelName,
            parameters: parameters
        )
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateJavaNestedModels(
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
                models += generateJavaNestedModels(
                    from: orderedNestedDict,
                    modelName: nestedModelName,
                    parameters: parameters
                )
                
                let (property, getterSetter) = generateJavaProperty(
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
                    models += generateJavaNestedModels(
                        from: orderedNestedDict,
                        modelName: nestedModelName,
                        parameters: parameters
                    )
                    
                    let (property, getterSetter) = generateJavaProperty(
                        for: key,
                        value: arrayValue,
                        useGettersSetters: parameters.useGettersSetters
                    )
                    properties.append(property)
                    if parameters.useGettersSetters {
                        gettersSetters.append(getterSetter)
                    }
                } else {
                    let (property, getterSetter) = generateJavaProperty(
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
                let (property, getterSetter) = generateJavaProperty(
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
        
        let imports = generateJavaImports(parameters: parameters)
        let annotations = generateJavaAnnotations(parameters: parameters)
        let propertiesStr = properties.joined(separator: "\n")
        let gettersSettersStr = gettersSetters.joined(separator: "\n\n")
        
        let model = """
        package \(parameters.packageName);
        
        \(imports)
        
        \(annotations)
        public class \(modelName) {
        \(propertiesStr)
        \(gettersSettersStr)
        }
        """
        
        return [model] + models
    }
    
    private static func generateJavaProperty(
        for key: String,
        value: Any,
        useGettersSetters: Bool
    ) -> (property: String, getterSetter: String) {
        let javaKey = key.lowercasedFirstLetter()
        let typeInfo = TypeUtilities.determineJavaType(from: value)
        
        let property = "    private \(typeInfo.type) \(javaKey);"
        
        var getterSetter = ""
        if useGettersSetters {
            let capitalizedKey = key.uppercasedFirstLetter()
            getterSetter = """
                public \(typeInfo.type) get\(capitalizedKey)() {
                    return \(javaKey);
                }
                
                public void set\(capitalizedKey)(\(typeInfo.type) \(javaKey)) {
                    this.\(javaKey) = \(javaKey);
                }
            """
        }
        
        return (property, getterSetter)
    }
    
    private static func generateJavaImports(parameters: Parameters) -> String {
        var imports = ["import java.io.Serializable;"]
        if parameters.useLombok {
            imports.append("import lombok.Data;")
        }
        return imports.joined(separator: "\n")
    }
    
    private static func generateJavaAnnotations(parameters: Parameters) -> String {
        var annotations = [String]()
        if parameters.useLombok {
            annotations.append("@Data")
        }
        if parameters.useSerializable {
            annotations.append("public class implements Serializable")
        }
        return annotations.joined(separator: "\n")
    }
}