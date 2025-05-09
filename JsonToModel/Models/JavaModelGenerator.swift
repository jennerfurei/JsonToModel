import Foundation

struct JavaModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useLombok: Bool
        let useGettersSetters: Bool
        let useSerializable: Bool
        let packageName: String
        let useWrapperTypes: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Java generator")
        }
        
        let parameters = Parameters(
            useLombok: params["useLombok"] as? Bool ?? true,
            useGettersSetters: params["useGettersSetters"] as? Bool ?? false,
            useSerializable: params["useSerializable"] as? Bool ?? true,
            packageName: params["packageName"] as? String ?? "com.example.model",
            useWrapperTypes: params["useWrapperTypes"] as? Bool ?? false
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
        
        let allModels = generateJavaNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateJavaNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        isArrayItem: Bool = false
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        var gettersSetters = [String]()
        
        let sortedKeys = jsonDict.keys.sorted()
        
        for key in sortedKeys {
            guard let value = jsonDict[key] else { continue }
            
            let (property, getterSetter, nestedModels) = generateJavaPropertyAndModels(
                for: key,
                value: value,
                modelName: modelName,
                parameters: parameters
            )
            
            properties.append(property)
            if parameters.useGettersSetters {
                gettersSetters.append(getterSetter)
            }
            models += nestedModels
        }
        
        let imports = generateJavaImports(for: properties, parameters: parameters)
        let annotations = generateJavaAnnotations(parameters: parameters)
        let serialVersionUID = parameters.useSerializable ? "\n    private static final long serialVersionUID = 1L;" : ""
        
        let model = """
        package \(parameters.packageName);
        
        \(imports)
        
        \(annotations)
        public class \(modelName)\(parameters.useSerializable ? " implements Serializable" : "") {\(serialVersionUID)
        \(properties.joined(separator: "\n"))
        \(gettersSetters.joined(separator: "\n\n"))
        }
        """
        
        return [model] + models
    }
    
    private static func generateJavaPropertyAndModels(
        for key: String,
        value: Any,
        modelName: String,
        parameters: Parameters
    ) -> (property: String, getterSetter: String, models: [String]) {
        let javaKey = key.lowercasedFirstLetter()
        let (typeString, nestedModels) = getJavaTypeInfo(
            for: value,
            key: key,
            modelName: modelName,
            parameters: parameters
        )
        
        let property = "    private \(typeString) \(javaKey);"
        
        var getterSetter = ""
        if parameters.useGettersSetters {
            let capitalizedKey = key.uppercasedFirstLetter()
            let getterPrefix = typeString == "boolean" ? "is" : "get"
            
            getterSetter = """
                public \(typeString) \(getterPrefix)\(capitalizedKey)() {
                    return this.\(javaKey);
                }
                
                public void set\(capitalizedKey)(\(typeString) \(javaKey)) {
                    this.\(javaKey) = \(javaKey);
                }
            """
        }
        
        return (property, getterSetter, nestedModels)
    }
    
    private static func getJavaTypeInfo(
        for value: Any,
        key: String,
        modelName: String,
        parameters: Parameters
    ) -> (typeString: String, models: [String]) {
        var models = [String]()
        var typeStr = "Object"
        
        switch value {
        case is String:
            typeStr = "String"
        case is Int, is Bool:
            let numberValue = value as? NSNumber
            if numberValue != nil && isBoolean(numberValue!) {
                typeStr = parameters.useWrapperTypes ? "Boolean" : "boolean"
            } else {
                typeStr = parameters.useWrapperTypes ? "Integer" : "int"
            }
        case is Double, is Float:
            typeStr = parameters.useWrapperTypes ? "Double" : "double"

        case let dict as [String: Any]:
            let nestedModelName = key.uppercasedFirstLetter()
            models += generateJavaNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters,
                isArrayItem: true
            )
            typeStr = nestedModelName
        case let array as [Any]:
            if let first = array.first {
                let (elementType, nested) = getJavaTypeInfo(
                    for: first,
                    key: key,
                    modelName: modelName,
                    parameters: parameters
                )
                models += nested
                typeStr = "List<\(elementType)>"
            } else {
                typeStr = "List<Object>"
            }
        case is NSNull:
            typeStr = "Object"
        default:
            typeStr = "Object"
        }
        
        return (typeStr, models)
    }
    
    private static func generateJavaImports(for properties: [String], parameters: Parameters) -> String {
        var imports = Set<String>()
        
        if parameters.useSerializable {
            imports.insert("import java.io.Serializable;")
        }
        
        if parameters.useLombok {
            imports.insert("import lombok.Data;")
        }
        
        if properties.contains(where: { $0.contains("List<") }) {
            imports.insert("import java.util.List;")
        }
        
        return imports.sorted().joined(separator: "\n")
    }
    
    private static func generateJavaAnnotations(parameters: Parameters) -> String {
        var annotations = [String]()
        if parameters.useLombok {
            annotations.append("@Data")
        }
        return annotations.joined(separator: "\n")
    }
}
