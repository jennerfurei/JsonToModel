//
//  ObjCModelGenerator.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

struct ObjCModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let inheritance: String
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Objective-C generator")
        }
        
        let parameters = Parameters(
            inheritance: params["inheritance"] as? String ?? ": NSObject"
        )
        
        let result = try generateObjectiveCModel(from: json, modelName: modelName, parameters: parameters)
        return "// \(modelName).h\n\(result.header)\n\n// \(modelName).m\n\(result.implementation)"
    }
    
    static func supportedLanguages() -> [String] {
        return ["Objective-C"]
    }
    
    private static func generateObjectiveCModel(
        from json: String,
        modelName: String,
        parameters: Parameters
    ) throws -> (header: String, implementation: String) {
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
        let orderedDict = dicToArraydic(source: jsonDict)
        
        return generateObjectiveCNestedModels(
            from: orderedDict,
            modelName: modelName,
            inheritance: parameters.inheritance
        )
    }
    
    private static func dicToArraydic(source: [String : Any]) -> [(key: String, value: Any)] {
        let sortedKeys = source.keys.sorted()
        var orderedDict = [(key: String, value: Any)]()
        for key in sortedKeys {
            orderedDict.append((key, source[key]!))
        }
        return orderedDict
    }
    
    private static func generateObjectiveCNestedModels(
        from jsonDict: [(key: String, value: Any)],
        modelName: String,
        inheritance: String
    ) -> (header: String, implementation: String) {
        var headerProperties = [String]()
        var implementationProperties = [String]()
        var nestedClasses = [String]()
        
        
        for (key, value) in jsonDict {
            let propertyName = key.lowercasedFirstLetter()
            let typeInfo = TypeUtilities.determineObjCType(from: value)
            
            var propertyDeclaration: String
            if typeInfo.isPrimitive {
                // 对于基本类型，使用更简洁的声明方式
                propertyDeclaration = "@property (nonatomic, assign) \(typeInfo.type) \(propertyName);"
            } else {
                // 对于对象类型
                let memorySemantic = typeInfo.type == "NSString" ? "copy" : "strong"
                propertyDeclaration = "@property (nonatomic, \(memorySemantic)) \(typeInfo.storageType) \(propertyName);"
            }
            
            headerProperties.append(propertyDeclaration)
            
            // 为对象类型生成懒初始化
            if !typeInfo.isPrimitive {
                let implementation = """
                - (\(typeInfo.storageType))\(propertyName) {
                    if (!_\(propertyName)) {
                        _\(propertyName) = [\(typeInfo.type) new];
                    }
                    return _\(propertyName);
                }
                """
                implementationProperties.append(implementation)
            }
            
            // Handle nested models
            if let nestedDict = value as? [String: Any] {
                let nestedModelName = key.uppercasedFirstLetter()
                let orderedDict = dicToArraydic(source: nestedDict)
                let nestedResult = generateObjectiveCNestedModels(
                    from: orderedDict,
                    modelName: nestedModelName,
                    inheritance: ": NSObject"
                )
                nestedClasses.append(nestedResult.header)
                nestedClasses.append(nestedResult.implementation)
            } else if let arrayValue = value as? [Any], !arrayValue.isEmpty, let firstElement = arrayValue[0] as? [String: Any] {
                let nestedModelName = key.uppercasedFirstLetter() + "Item"
                let orderedDict = dicToArraydic(source: firstElement)
                let nestedResult = generateObjectiveCNestedModels(
                    from: orderedDict,
                    modelName: nestedModelName,
                    inheritance: ": NSObject"
                )
                nestedClasses.append(nestedResult.header)
                nestedClasses.append(nestedResult.implementation)
            }
        }
        
        let header = """
        #import <Foundation/Foundation.h>
        
        @interface \(modelName)\(inheritance)
        
        \(headerProperties.joined(separator: "\n"))
        
        @end
        """
        
        let implementation = """
        #import "\(modelName).h"
        
        @implementation \(modelName)
        
        \(implementationProperties.joined(separator: "\n\n"))
        
        @end
        """
        
        let nested = nestedClasses.joined(separator: "\n\n")
        
        return (
            header: nested.isEmpty ? header : "\(nested)\n\n\(header)",
            implementation: nested.isEmpty ? implementation : "\(nested)\n\n\(implementation)"
        )
    }
}
