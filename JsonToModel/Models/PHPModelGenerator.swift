import Foundation

struct PHPModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useGettersSetters: Bool
        let namespace: String
        let useTypedProperties: Bool // PHP 7.4+ 类型属性
        let useConstructor: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for PHP generator")
        }
        
        let parameters = Parameters(
            useGettersSetters: params["useGettersSetters"] as? Bool ?? true,
            namespace: params["namespace"] as? String ?? "App\\Models",
            useTypedProperties: params["useTypedProperties"] as? Bool ?? true,
            useConstructor: params["useConstructor"] as? Bool ?? true
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
        
        let allModels = generatePHPNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generatePHPNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        isArrayItem: Bool = false
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        var gettersSetters = [String]()
        var constructorParams = [String]()
        var constructorAssignments = [String]()
        
        let sortedKeys = jsonDict.keys.sorted()
        
        for key in sortedKeys {
            guard let value = jsonDict[key] else { continue }
            
            let (property, getterSetter, nestedModels, constructorParam, constructorAssignment) = generatePHPPropertyAndModels(
                for: key,
                value: value,
                modelName: modelName,
                parameters: parameters
            )
            
            properties.append(property)
            gettersSetters.append(getterSetter)
            models += nestedModels
            constructorParams.append(constructorParam)
            constructorAssignments.append(constructorAssignment)
        }
        
        let propertiesStr = properties.joined(separator: "\n")
        let gettersSettersStr = gettersSetters.joined(separator: "\n\n")
        
        // 生成构造函数
        let constructorStr: String
        if parameters.useConstructor && !constructorParams.isEmpty {
            constructorStr = """
            
                public function __construct(
            \(constructorParams.joined(separator: ",\n"))
                ) {
            \(constructorAssignments.joined(separator: "\n"))
                }
            """
        } else {
            constructorStr = ""
        }
        
        let model = """
        <?php
        
        namespace \(parameters.namespace);
        
        class \(modelName)
        {
        \(propertiesStr)\(constructorStr)
        \(gettersSettersStr)
        }
        """
        
        return [model] + models
    }
    
    private static func generatePHPPropertyAndModels(
        for key: String,
        value: Any,
        modelName: String,
        parameters: Parameters
    ) -> (property: String, getterSetter: String, models: [String], constructorParam: String, constructorAssignment: String) {
        let phpKey = key.lowercasedFirstLetter()
        let (typeString, nestedModels, _) = getPHPTypeInfo(
            for: value,
            key: key,
            modelName: modelName,
            parameters: parameters
        )
        
        // 属性声明
        let typePrefix = parameters.useTypedProperties ? "\(typeString) " : ""
        let property = "    private \(typePrefix)$\(phpKey);"
        
        // Getter/Setter
        var getterSetter = ""
        if parameters.useGettersSetters {
            let capitalizedKey = key.uppercasedFirstLetter()
            let returnType = parameters.useTypedProperties ? ": \(typeString)" : ""
            let paramType = parameters.useTypedProperties ? "\(typeString) " : ""
            
            getterSetter = """
                public function get\(capitalizedKey)()\(returnType)
                {
                    return $this->\(phpKey);
                }
                
                public function set\(capitalizedKey)(\(paramType)$\(phpKey)): void
                {
                    $this->\(phpKey) = $\(phpKey);
                }
            """
        }
        
        // 构造函数参数和赋值
        let constructorParam = "        \(typeString) $\(phpKey)"
        let constructorAssignment = "        $this->\(phpKey) = $\(phpKey);"
        
        return (property, getterSetter, nestedModels, constructorParam, constructorAssignment)
    }
    
    private static func getPHPTypeInfo(
        for value: Any,
        key: String,
        modelName: String,
        parameters: Parameters
    ) -> (typeString: String, models: [String], isObject: Bool) {
        var models = [String]()
        var typeStr = ""
        var isObject = false
        
        switch value {
        case is String:
            typeStr = "string"
        case is Int, is Bool:
            let numberValue = value as? NSNumber
            if numberValue != nil && isBoolean(numberValue!) {
                typeStr = "bool"
            } else {
                typeStr = "int"
            }
        case is Double, is Float:
            typeStr = "float"

        case let dict as [String: Any]:
            let nestedModelName = key.uppercasedFirstLetter()
            models += generatePHPNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters,
                isArrayItem: true
            )
            typeStr = nestedModelName
            isObject = true
        case let array as [Any]:
            if let first = array.first {
                let (_, nested, _) = getPHPTypeInfo(
                    for: first,
                    key: key,
                    modelName: modelName,
                    parameters: parameters
                )
                models += nested
                typeStr = "array" // PHP 原生数组
                // 可以添加 PHPDoc 注释说明数组类型
                // /​**​ @var \(elementType)[] */
            } else {
                typeStr = "array"
            }
        case is NSNull:
            typeStr = "mixed"
        default:
            typeStr = "mixed"
        }
        
        return (typeStr, models, isObject)
    }
}

