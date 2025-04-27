//
//  ModelGeneratorProtocol.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

protocol ModelGeneratorProtocol {
    static func generateModel(from json: String, modelName: String, additionalParameters: [String: Any]) throws -> String
    static func supportedLanguages() -> [String]
}

extension ModelGeneratorProtocol {
    // 安全解析JSON的方法
    static func safeParseJSON(_ jsonString: String) throws -> Any {
        guard let data = jsonString.data(using: .utf8) else {
            throw ModelGenerationError(type: .invalidJSON)
        }
        
        do {
            // 明确指定允许的JSON顶层对象类型
            let options: JSONSerialization.ReadingOptions = [.allowFragments]
            let jsonObject = try JSONSerialization.jsonObject(
                with: data,
                options: options
            )
            
            // 验证顶层对象类型
            guard jsonObject is [String: Any] || jsonObject is [Any] else {
                throw ModelGenerationError(type: .invalidJSON)
            }
            
            return jsonObject
        } catch {
            throw ModelGenerationError(type: .invalidJSON)
        }
    }
}


struct ModelGenerationError: Error {
    enum ErrorType {
        case invalidJSON
        case emptyInput
        case invalidModelName
        case unsupportedType
    }
    
    let type: ErrorType
    let description: String
    
    init(type: ErrorType, description: String? = nil) {
        self.type = type
        self.description = description ?? {
            switch type {
            case .invalidJSON: return "Invalid JSON format"
            case .emptyInput: return "Input JSON is empty"
            case .invalidModelName: return "Model name is invalid"
            case .unsupportedType: return "Unsupported type in JSON"
            }
        }()
    }
}

extension ModelGenerationError: LocalizedError {
    var errorDescription: String? { description }
}



