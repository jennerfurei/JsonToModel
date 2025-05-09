import Foundation

struct CPPModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useSmartPointers: Bool
        let useConstReferences: Bool
        let namespace: String
        let useMoveSemantics: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for C++ generator")
        }
        
        let parameters = Parameters(
            useSmartPointers: params["useSmartPointers"] as? Bool ?? true,
            useConstReferences: params["useConstReferences"] as? Bool ?? true,
            namespace: params["namespace"] as? String ?? "model",
            useMoveSemantics: params["useMoveSemantics"] as? Bool ?? true
        )
        
        return try generateCPPModel(from: json, modelName: modelName, parameters: parameters)
    }
    
    static func supportedLanguages() -> [String] {
        return ["C++"]
    }
    
    private static func generateCPPModel(
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
        
        let allModels = generateCPPNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters
        )
        
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateCPPNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        isArrayItem: Bool = false
    ) -> [String] {
        var models = [String]()
        var privateMembers = [String]()
        var publicMethods = [String]()
        var includes = Set<String>(["#include <string>", "#include <vector>"])
        
        let sortedKeys = jsonDict.keys.sorted()
        
        var constructorParams = [String]()
        var constructorInitializers = [String]()
        
        for key in sortedKeys {
            guard let value = jsonDict[key] else { continue }
            
            let (memberDecl, methods, nestedModels, typeInfo) = generateCPPClassMember(
                for: key,
                value: value,
                modelName: modelName,
                parameters: parameters
            )
            
            privateMembers.append(memberDecl)
            publicMethods += methods
            models += nestedModels
            includes.formUnion(typeInfo.requiredIncludes)
            
            // Build constructor
            let paramType = parameters.useConstReferences && !typeInfo.isPrimitive ?
                "const \(typeInfo.type)&" : typeInfo.type
            let paramName = "new_" + key.lowercasedFirstLetter()
            
            constructorParams.append("        \(paramType) \(paramName)")
            
            if parameters.useMoveSemantics && typeInfo.isMovable {
                constructorInitializers.append("    \(key.lowercasedFirstLetter())_(std::move(\(paramName)))")
            } else {
                constructorInitializers.append("    \(key.lowercasedFirstLetter())_(\(paramName))")
            }
        }
        
        // Generate full class
        let includeSection = Array(includes).sorted().joined(separator: "\n")
        let privateSection = privateMembers.joined(separator: "\n")
        let publicSection = publicMethods.joined(separator: "\n\n")
        
        let constructor: String
        if !constructorParams.isEmpty {
            constructor = """
            
            public:
                \(modelName)(\(constructorParams.joined(separator: ",\n")))
                : \(constructorInitializers.joined(separator: ",\n"))
                {}
            """
        } else {
            constructor = ""
        }
        
        let model = """
        #pragma once
        
        \(includeSection)
        
        namespace \(parameters.namespace) {
        
        class \(modelName) {
        private:
        \(privateSection)
        \(constructor)
        \(publicSection)
        };
        
        } // namespace \(parameters.namespace)
        """
        
        return [model] + models
    }
    
    private static func generateCPPClassMember(
        for key: String,
        value: Any,
        modelName: String,
        parameters: Parameters
    ) -> (memberDecl: String, methods: [String], nestedModels: [String], typeInfo: CPPTypeInfo) {
        let memberName = key.lowercasedFirstLetter() + "_"
        var nestedModels = [String]()
        var methods = [String]()
        
        // 使用新的严格类型判断
        let typeInfo: CPPTypeInfo
        var requiredIncludes = Set<String>()
        
        // 严格类型检查
        if let boolValue = value as? Bool {
            typeInfo = CPPTypeInfo(type: "bool", requiredIncludes: [], isMovable: false)
        }
        else if let stringValue = value as? String {
            typeInfo = CPPTypeInfo(type: "std::string", requiredIncludes: ["#include <string>"], isMovable: true)
        }
        else if let intValue = value as? Int {
            typeInfo = CPPTypeInfo(type: "int", requiredIncludes: [], isMovable: false)
        }
        else if let doubleValue = value as? Double {
            typeInfo = CPPTypeInfo(type: "double", requiredIncludes: [], isMovable: false)
        }
        else if let dict = value as? [String: Any] {
            let nestedModelName = key.uppercasedFirstLetter()
            nestedModels += generateCPPNestedModels(
                from: dict,
                modelName: nestedModelName,
                parameters: parameters,
                isArrayItem: true
            )
            
            if parameters.useSmartPointers {
                typeInfo = CPPTypeInfo(
                    type: "std::unique_ptr<\(nestedModelName)>",
                    requiredIncludes: ["#include <memory>", "#include \"\(nestedModelName.lowercased()).h\""],
                    isMovable: true
                )
            } else {
                typeInfo = CPPTypeInfo(
                    type: nestedModelName,
                    requiredIncludes: ["#include \"\(nestedModelName.lowercased()).h\""],
                    isMovable: true
                )
            }
        }
        else if let array = value as? [Any], let firstElement = array.first {
            let elementTypeInfo: CPPTypeInfo
            
            // 递归处理数组元素类型
            if let boolElement = firstElement as? Bool {
                elementTypeInfo = CPPTypeInfo(type: "bool", requiredIncludes: [], isMovable: false)
            }
            else if let stringElement = firstElement as? String {
                elementTypeInfo = CPPTypeInfo(type: "std::string", requiredIncludes: ["#include <string>"], isMovable: true)
            }
            else if let intElement = firstElement as? Int {
                elementTypeInfo = CPPTypeInfo(type: "int", requiredIncludes: [], isMovable: false)
            }
            else if let dictElement = firstElement as? [String: Any] {
                let nestedModelName = key.uppercasedFirstLetter() + "Item"
                nestedModels += generateCPPNestedModels(
                    from: dictElement,
                    modelName: nestedModelName,
                    parameters: parameters,
                    isArrayItem: true
                )
                elementTypeInfo = CPPTypeInfo(
                    type: nestedModelName,
                    requiredIncludes: ["#include \"\(nestedModelName.lowercased()).h\""],
                    isMovable: true
                )
            }
            else {
                elementTypeInfo = CPPTypeInfo(type: "void", requiredIncludes: [], isMovable: false)
            }
            
            let vectorInclude = Set(["#include <vector>"])
            let combinedIncludes = vectorInclude.union(elementTypeInfo.requiredIncludes)
            
            typeInfo = CPPTypeInfo(
                type: "std::vector<\(elementTypeInfo.type)>",
                requiredIncludes: combinedIncludes,
                isMovable: true
            )
        }
        else {
            typeInfo = CPPTypeInfo(type: "void", requiredIncludes: [], isMovable: false)
        }
        
        // 生成成员变量声明
        let memberDecl = "    \(typeInfo.type) \(memberName);"
        
        // 生成getter/setter
        let capitalizedKey = key.uppercasedFirstLetter()
        
        // Getter
        let returnType: String
        if parameters.useConstReferences && typeInfo.isReferenceType {
            returnType = "const \(typeInfo.type)&"
        } else {
            returnType = typeInfo.type
        }
        
        let getter = "    \(returnType) get\(capitalizedKey)() const { return \(memberName); }"
        methods.append(getter)
        
        // Setter
        let paramType: String
        if parameters.useConstReferences && !typeInfo.isPrimitive {
            paramType = "const \(typeInfo.type)&"
        } else {
            paramType = typeInfo.type
        }
        
        let setter: String
        if parameters.useMoveSemantics && typeInfo.isMovable {
            setter = """
                void set\(capitalizedKey)(\(paramType) new_\(memberName)) {
                    \(memberName) = std::move(new_\(memberName));
                }
            """
        } else {
            setter = """
                void set\(capitalizedKey)(\(paramType) new_\(memberName)) {
                    \(memberName) = new_\(memberName);
                }
            """
        }
        methods.append(setter)
        
        return (memberDecl, methods, nestedModels, typeInfo)
    }
}

struct CPPTypeInfo {
    let type: String
    let requiredIncludes: Set<String>
    let isMovable: Bool
    
    var isPrimitive: Bool {
        return ["int", "double", "float", "bool"].contains(type)
    }
    
    var isReferenceType: Bool {
        return !isPrimitive && type != "void"
    }
}
