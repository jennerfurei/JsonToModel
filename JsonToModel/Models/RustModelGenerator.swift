import Foundation

struct RustModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useSerde: Bool
        let useClone: Bool
        let useDebug: Bool
        let useDefault: Bool
        let useOption: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Rust generator")
        }
        
        let parameters = Parameters(
            useSerde: params["useSerde"] as? Bool ?? true,
            useClone: params["useClone"] as? Bool ?? true,
            useDebug: params["useDebug"] as? Bool ?? true,
            useDefault: params["useDefault"] as? Bool ?? false,
            useOption: params["useOption"] as? Bool ?? true
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
        
        guard let jsonData = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
              let jsonDict = jsonObject as? [String: Any] else {
            throw ModelGenerationError(type: .invalidJSON)
        }
        
        var generatedStructs = Set<String>()
        let allModels = generateRustNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters,
            generatedStructs: &generatedStructs
        )
        
        // 添加必要的 use 声明
        let uses = generateUseStatements(parameters: parameters)
        return uses + "\n\n" + allModels.joined(separator: "\n\n")
    }
    
    private static func generateUseStatements(parameters: Parameters) -> String {
        var statements = [String]()
        if parameters.useSerde {
            statements.append("use serde::{Serialize, Deserialize};")
        }
        if parameters.useOption {
            statements.append("use std::collections::HashMap;")
        }
        return statements.joined(separator: "\n")
    }
    
    private static func generateRustNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        generatedStructs: inout Set<String>
    ) -> [String] {
        // 防止重复生成
        if generatedStructs.contains(modelName) {
            return []
        }
        generatedStructs.insert(modelName)
        
        var models = [String]()
        var properties = [String]()
        
        for (key, value) in jsonDict.sorted(by: { $0.key < $1.key }) {
            let rustKey = key.lowercasedFirstLetter()
            let (typeInfo, nestedModelName) = determineRustType(
                value: value,
                key: key,
                parameters: parameters
            )
            
            // 处理嵌套对象
            if let nestedDict = value as? [String: Any] {
                models += generateRustNestedModels(
                    from: nestedDict,
                    modelName: nestedModelName,
                    parameters: parameters,
                    generatedStructs: &generatedStructs
                )
            }
            // 处理数组中的嵌套对象
            else if let array = value as? [Any], let firstElement = array.first {
                if let nestedDict = firstElement as? [String: Any] {
                    models += generateRustNestedModels(
                        from: nestedDict,
                        modelName: nestedModelName,
                        parameters: parameters,
                        generatedStructs: &generatedStructs
                    )
                }
            }
            
            // 添加属性
            var property = "    pub \(rustKey): "
            if parameters.useOption && typeInfo.isOptional {
                property += "Option<"
            }
            property += typeInfo.type
            if parameters.useOption && typeInfo.isOptional {
                property += ">"
            }
            if parameters.useDefault {
                property += " = " + typeInfo.defaultValue
            }
            property += ","
            properties.append(property)
        }
        
        // 生成派生宏
        let derives = generateRustDerives(parameters: parameters)
        
        // 构建结构体
        let model = """
        \(derives)
        pub struct \(modelName) {
        \(properties.joined(separator: "\n"))
        }
        """
        
        return [model] + models
    }
    
    private static func determineRustType(
        value: Any,
        key: String,
        parameters: Parameters
    ) -> (typeInfo: RustTypeInfo, nestedModelName: String) {
        let nestedModelName = key.uppercasedFirstLetter()
        
        switch value {
        case is String:
            return (RustTypeInfo(type: "String", isOptional: true, defaultValue: "String::new()"), "")
        case is Int, is Bool:
            let numberValue = value as? NSNumber
            if numberValue != nil && isBoolean(numberValue!) {
                return (RustTypeInfo(type: "bool", isOptional: false, defaultValue: "false"), "")
            } else {
                return (RustTypeInfo(type: "i32", isOptional: false, defaultValue: "0"), "")
            }
           
        case is Double, is Float:
            return (RustTypeInfo(type: "f64", isOptional: false, defaultValue: "0.0"), "")

        case let dict as [String: Any]:
            return (RustTypeInfo(type: nestedModelName, isOptional: parameters.useOption, defaultValue: "Default::default()"), nestedModelName)
        case let array as [Any]:
            if let first = array.first {
                let (elementType, _) = determineRustType(value: first, key: key, parameters: parameters)
                return (RustTypeInfo(type: "Vec<\(elementType.type)>", isOptional: false, defaultValue: "Vec::new()"), nestedModelName + "Item")
            }
            return (RustTypeInfo(type: "Vec<String>", isOptional: false, defaultValue: "Vec::new()"), "")
        default:
            return (RustTypeInfo(type: "String", isOptional: true, defaultValue: "String::new()"), "")
        }
    }
    
    private static func generateRustDerives(parameters: Parameters) -> String {
        var derives = ["#[derive("]
        var traits = [String]()
        
        if parameters.useSerde {
            traits.append("Serialize")
            traits.append("Deserialize")
        }
        if parameters.useClone {
            traits.append("Clone")
        }
        if parameters.useDebug {
            traits.append("Debug")
        }
        if parameters.useDefault {
            traits.append("Default")
        }
        
        derives.append(traits.joined(separator: ", "))
        derives.append(")]")
        return derives.joined(separator: "")
    }
}

struct RustTypeInfo {
    let type: String
    let isOptional: Bool
    let defaultValue: String
}
