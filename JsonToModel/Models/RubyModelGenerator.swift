import Foundation

struct RubyModelGenerator: ModelGeneratorProtocol {
    struct Parameters {
        let useInitialize: Bool
        let moduleName: String
        let useSnakeCase: Bool
        let addToHashMethod: Bool
    }
    
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String {
        guard let params = additionalParameters as? [String: AnyHashable] else {
            throw ModelGenerationError(type: .unsupportedType, description: "Invalid parameters for Ruby generator")
        }
        
        let parameters = Parameters(
            useInitialize: params["useInitialize"] as? Bool ?? true,
            moduleName: params["moduleName"] as? String ?? "Model",
            useSnakeCase: params["useSnakeCase"] as? Bool ?? true,
            addToHashMethod: params["addToHashMethod"] as? Bool ?? false
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
        
        guard let jsonData = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
              let jsonDict = jsonObject as? [String: Any] else {
            throw ModelGenerationError(type: .invalidJSON)
        }
        
        var generatedClasses = Set<String>()
        let allModels = generateRubyNestedModels(
            from: jsonDict,
            modelName: modelName,
            parameters: parameters,
            generatedClasses: &generatedClasses
        )
        
        return allModels.joined(separator: "\n\n")
    }
    
    private static func generateRubyNestedModels(
        from jsonDict: [String: Any],
        modelName: String,
        parameters: Parameters,
        generatedClasses: inout Set<String>
    ) -> [String] {
        // 防止重复生成
        if generatedClasses.contains(modelName) {
            return []
        }
        generatedClasses.insert(modelName)
        
        var models = [String]()
        var properties = [String]()
        var initParams = [String]()
        var initAssignments = [String]()
        var toHashLines = [String]()
        
        for (key, value) in jsonDict.sorted(by: { $0.key < $1.key }) {
            let rubyKey = parameters.useSnakeCase ?
                key.camelCaseToSnakeCase() :
                key.lowercasedFirstLetter()
            
            // 处理属性
            properties.append("    attr_accessor :\(rubyKey)")
            
            // 处理嵌套对象
            if let nestedDict = value as? [String: Any] {
                let nestedModelName = key.uppercasedFirstLetter()
                models += generateRubyNestedModels(
                    from: nestedDict,
                    modelName: nestedModelName,
                    parameters: parameters,
                    generatedClasses: &generatedClasses
                )
                
                initParams.append("      \(rubyKey): nil")
                initAssignments.append("      @\(rubyKey) = \(rubyKey)")
                toHashLines.append("      \(rubyKey): \(rubyKey)&.to_hash")
            }
            // 处理数组
            else if let array = value as? [Any], !array.isEmpty {
                if let firstElement = array.first as? [String: Any] {
                    let nestedModelName = key.uppercasedFirstLetter() + "Item"
                    models += generateRubyNestedModels(
                        from: firstElement,
                        modelName: nestedModelName,
                        parameters: parameters,
                        generatedClasses: &generatedClasses
                    )
                    
                    initParams.append("      \(rubyKey): []")
                    initAssignments.append("      @\(rubyKey) = \(rubyKey)")
                    toHashLines.append("      \(rubyKey): \(rubyKey).map(&:to_hash)")
                } else {
                    initParams.append("      \(rubyKey): []")
                    initAssignments.append("      @\(rubyKey) = \(rubyKey)")
                    toHashLines.append("      \(rubyKey): \(rubyKey).dup")
                }
            }
            // 处理基本类型
            else {
                let defaultValue: String
                switch value {
                case is String: defaultValue = "nil"
                case is Int, is Bool: 
                    let numberValue = value as? NSNumber
                    if numberValue != nil && isBoolean(numberValue!) {
                        defaultValue = "false"
                    } else {
                        defaultValue = "nil"
                    }
                case is Double, is Float: defaultValue = "nil"
                default: defaultValue = "nil"
                }
                
                initParams.append("      \(rubyKey): \(defaultValue)")
                initAssignments.append("      @\(rubyKey) = \(rubyKey)")
                toHashLines.append("      \(rubyKey): \(rubyKey)")
            }
        }
        
        // 构建类定义
        var classDefinition = """
        module \(parameters.moduleName)
          class \(modelName)
        \(properties.joined(separator: "\n"))
        """
        
        // 添加初始化方法
        if parameters.useInitialize && !initParams.isEmpty {
            classDefinition += """
            
                def initialize(
            \(initParams.joined(separator: ",\n"))
                )
            \(initAssignments.joined(separator: "\n"))
                end \n
            """
        }
        
        // 添加to_hash方法
        if parameters.addToHashMethod && !toHashLines.isEmpty {
            classDefinition += """
            
                def to_hash
                  {
            \(toHashLines.joined(separator: ",\n"))
                  }
                end  \n
            """
        }

        classDefinition += """
          end
        end
        """
        
        return [classDefinition] + models
    }
}

