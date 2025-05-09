import Foundation

struct PythonModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useDataclass: Bool
        let useTypeHints: Bool
        let makeFieldsOptional: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Python generator")
        }
        
        let parameters = Parameters(
            useDataclass: params["useDataclass"] as? Bool ?? true,
            useTypeHints: params["useTypeHints"] as? Bool ?? true,
            makeFieldsOptional: params["makeFieldsOptional"] as? Bool ?? false
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
        
        // 生成所有嵌套模型
        let allModels = generatePythonNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        // 添加必要的导入语句
        let imports = """
        from dataclasses import dataclass
        from typing import List, Dict, Union, Optional
        \(parameters.useDataclass ? "" : "\n# Remove @dataclass decorator if not needed")
        
        """
        
        return imports + allModels.joined(separator: "\n\n")
    }
    
    private static func generatePythonNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        isArrayItem: Bool = false
    ) -> [String] {
        var models = [String]()
        var properties = [String]()
        
        // 对字段按键名排序
        let sortedKeys = jsonDict.keys.sorted()
        
        for key in sortedKeys {
            guard let value = jsonDict[key] else { continue }
            
            let pythonKey = key.lowercasedFirstLetter()
            let (typeString, nestedModels) = getTypeInfo(
                for: value,
                key: key,
                modelName: modelName,
                parameters: parameters
            )
            
            models += nestedModels
            
            // 构建属性行
            let typeSuffix = parameters.makeFieldsOptional ? " = None" : ""
            let propertyLine: String
            
            if parameters.useTypeHints {
                propertyLine = "    \(pythonKey): \(typeString)\(typeSuffix)"
            } else {
                propertyLine = "    \(pythonKey)\(typeSuffix)"
            }
            
            properties.append(propertyLine)
        }
        
        // 构建模型定义
        let decorator = parameters.useDataclass ? "@dataclass\n" : ""
        let modelDef = """
        \(decorator)class \(modelName):
        \(properties.joined(separator: "\n"))
        """
        
        return [modelDef] + models
    }
    
    private static func getTypeInfo(
        for value: Any,
        key: String,
        modelName: String,
        parameters: Parameters
    ) -> (typeString: String, models: [String]) {
        var models = [String]()
        var typeStr = "Any"
        
        switch value {
        case is String:
            typeStr = "str"
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
            models += generatePythonNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters
            )
            typeStr = nestedModelName
        case let array as [Any]:
            if let first = array.first {
                let (elementType, nested) = getTypeInfo(
                    for: first,
                    key: key + "Item",
                    modelName: modelName,
                    parameters: parameters
                )
                models += nested
                typeStr = "List[\(elementType)]"
            } else {
                typeStr = "List[Any]"
            }
        case is NSNull:
            typeStr = "Any" // 单独处理为 Optional
        default:
            typeStr = "Any"
        }
        
        // 处理 Optional 类型
        if parameters.makeFieldsOptional {
            if typeStr.hasPrefix("Optional[") || typeStr.hasPrefix("Union[") {
                // 已经是 Optional 类型，不再重复添加
            } else if typeStr.contains("|") {
                typeStr = "\(typeStr) | None"
            } else {
                typeStr = "\(typeStr) | None" // 使用 Python 3.10+ 的新语法
                // 或者使用旧语法: typeStr = "Optional[\(typeStr)]"
            }
        }
        
        return (typeStr, models)
    }
}

func isBoolean(_ value: NSNumber) -> Bool {
    // __NSCFBoolean 是 NSNumber 的子类，值是 true/false
    return String(cString: object_getClassName(value)) == "__NSCFBoolean"
}

