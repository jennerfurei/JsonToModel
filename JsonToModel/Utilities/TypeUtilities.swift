//
//  TypeUtilities.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

struct TypeUtilities {
    struct TypeInfo {
        let type: String
        let storageType: String
        let isPrimitive: Bool
        let initType: String
    }
    
    static func determineSwiftType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "Bool", storageType: "Bool", isPrimitive: true, initType: "Bool")
        case is Int:
            return TypeInfo(type: "Int", storageType: "Int", isPrimitive: true, initType: "Int")
        case is Double:
            return TypeInfo(type: "Double", storageType: "Double", isPrimitive: true, initType: "Double")
        case is String:
            return TypeInfo(type: "String", storageType: "String", isPrimitive: false, initType: "String")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "[Any]", storageType: "[Any]", isPrimitive: false, initType: "[Any]")
            }
            let elementType = determineSwiftType(from: array[0])
            return TypeInfo(
                type: "[\(elementType.type)]",
                storageType: "[\(elementType.storageType)]",
                isPrimitive: false,
                initType: "[\(elementType.initType)]"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "[String: Any]", storageType: "[String: Any]", isPrimitive: false, initType: "[String: Any]")
        default:
            return TypeInfo(type: "Any", storageType: "Any", isPrimitive: false, initType: "Any")
        }
    }
    
    static func determineObjCType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "BOOL", storageType: "BOOL", isPrimitive: true, initType: "BOOL")
        case is Int:
            return TypeInfo(type: "NSInteger", storageType: "NSInteger", isPrimitive: true, initType: "NSInteger")
        case is Double:
            return TypeInfo(type: "CGFloat", storageType: "CGFloat", isPrimitive: true, initType: "CGFloat")
        case is String:
            return TypeInfo(type: "NSString", storageType: "NSString *", isPrimitive: false, initType: "NSString *")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "NSArray", storageType: "NSArray *", isPrimitive: false, initType: "NSArray *")
            }
            let elementType = determineObjCType(from: array[0])
            return TypeInfo(
                type: "NSArray<\(elementType.type)>",
                storageType: "NSArray<\(elementType.type)> *",
                isPrimitive: false,
                initType: "NSArray<\(elementType.type)> *"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "NSDictionary", storageType: "NSDictionary *", isPrimitive: false, initType: "NSDictionary *")
        default:
            return TypeInfo(type: "id", storageType: "id", isPrimitive: false, initType: "id")
        }
    }
    
    static func determinePythonType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "bool", storageType: "bool", isPrimitive: true, initType: "bool")
        case is Int:
            return TypeInfo(type: "int", storageType: "int", isPrimitive: true, initType: "int")
        case is Double:
            return TypeInfo(type: "float", storageType: "float", isPrimitive: true, initType: "float")
        case is String:
            return TypeInfo(type: "str", storageType: "str", isPrimitive: false, initType: "str")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "List[Any]", storageType: "List[Any]", isPrimitive: false, initType: "List[Any]")
            }
            let elementType = determinePythonType(from: array[0])
            return TypeInfo(
                type: "List[\(elementType.type)]",
                storageType: "List[\(elementType.storageType)]",
                isPrimitive: false,
                initType: "List[\(elementType.initType)]"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "Dict[str, Any]", storageType: "Dict[str, Any]", isPrimitive: false, initType: "Dict[str, Any]")
        default:
            return TypeInfo(type: "Any", storageType: "Any", isPrimitive: false, initType: "Any")
        }
    }
    
    static func determineTypeScriptType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "boolean", storageType: "boolean", isPrimitive: true, initType: "boolean")
        case is Int, is Double:
            return TypeInfo(type: "number", storageType: "number", isPrimitive: true, initType: "number")
        case is String:
            return TypeInfo(type: "string", storageType: "string", isPrimitive: false, initType: "string")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "any[]", storageType: "any[]", isPrimitive: false, initType: "any[]")
            }
            let elementType = determineTypeScriptType(from: array[0])
            return TypeInfo(
                type: "\(elementType.type)[]",
                storageType: "\(elementType.storageType)[]",
                isPrimitive: false,
                initType: "\(elementType.initType)[]"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "Record<string, any>", storageType: "Record<string, any>", isPrimitive: false, initType: "Record<string, any>")
        default:
            return TypeInfo(type: "any", storageType: "any", isPrimitive: false, initType: "any")
        }
    }

    static func determineJavaType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "boolean", storageType: "boolean", isPrimitive: true, initType: "boolean")
        case is Int:
            return TypeInfo(type: "int", storageType: "int", isPrimitive: true, initType: "int")
        case is Double:
            return TypeInfo(type: "double", storageType: "double", isPrimitive: true, initType: "double")
        case is String:
            return TypeInfo(type: "String", storageType: "String", isPrimitive: false, initType: "String")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "List<Object>", storageType: "List<Object>", isPrimitive: false, initType: "List<Object>")
            }
            let elementType = determineJavaType(from: array[0])
            return TypeInfo(
                type: "List<\(elementType.type)>",
                storageType: "List<\(elementType.storageType)>",
                isPrimitive: false,
                initType: "List<\(elementType.initType)>"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "Map<String, Object>", storageType: "Map<String, Object>", isPrimitive: false, initType: "Map<String, Object>")
        default:
            return TypeInfo(type: "Object", storageType: "Object", isPrimitive: false, initType: "Object")
        }
    }
    
    static func determineKotlinType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "Boolean", storageType: "Boolean", isPrimitive: true, initType: "Boolean")
        case is Int:
            return TypeInfo(type: "Int", storageType: "Int", isPrimitive: true, initType: "Int")
        case is Double:
            return TypeInfo(type: "Double", storageType: "Double", isPrimitive: true, initType: "Double")
        case is String:
            return TypeInfo(type: "String", storageType: "String", isPrimitive: false, initType: "String")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "List<Any>", storageType: "List<Any>", isPrimitive: false, initType: "List<Any>")
            }
            let elementType = determineKotlinType(from: array[0])
            return TypeInfo(
                type: "List<\(elementType.type)>",
                storageType: "List<\(elementType.storageType)>",
                isPrimitive: false,
                initType: "List<\(elementType.initType)>"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "Map<String, Any>", storageType: "Map<String, Any>", isPrimitive: false, initType: "Map<String, Any>")
        default:
            return TypeInfo(type: "Any", storageType: "Any", isPrimitive: false, initType: "Any")
        }
    }
    
    static func determinePHPType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "bool", storageType: "bool", isPrimitive: true, initType: "bool")
        case is Int:
            return TypeInfo(type: "int", storageType: "int", isPrimitive: true, initType: "int")
        case is Double:
            return TypeInfo(type: "float", storageType: "float", isPrimitive: true, initType: "float")
        case is String:
            return TypeInfo(type: "string", storageType: "string", isPrimitive: false, initType: "string")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "array", storageType: "array", isPrimitive: false, initType: "array")
            }
            let elementType = determinePHPType(from: array[0])
            return TypeInfo(
                type: "array",
                storageType: "array",
                isPrimitive: false,
                initType: "array"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "array", storageType: "array", isPrimitive: false, initType: "array")
        default:
            return TypeInfo(type: "mixed", storageType: "mixed", isPrimitive: false, initType: "mixed")
        }
    }
    
    static func determineCPPType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "bool", storageType: "bool", isPrimitive: true, initType: "bool")
        case is Int:
            return TypeInfo(type: "int", storageType: "int", isPrimitive: true, initType: "int")
        case is Double:
            return TypeInfo(type: "double", storageType: "double", isPrimitive: true, initType: "double")
        case is String:
            return TypeInfo(type: "std::string", storageType: "std::string", isPrimitive: false, initType: "std::string")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "std::vector<void*>", storageType: "std::vector<void*>", isPrimitive: false, initType: "std::vector<void*>")
            }
            let elementType = determineCPPType(from: array[0])
            return TypeInfo(
                type: "std::vector<\(elementType.type)>",
                storageType: "std::vector<\(elementType.storageType)>",
                isPrimitive: false,
                initType: "std::vector<\(elementType.initType)>"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "std::map<std::string, void*>", storageType: "std::map<std::string, void*>", isPrimitive: false, initType: "std::map<std::string, void*>")
        default:
            return TypeInfo(type: "void*", storageType: "void*", isPrimitive: false, initType: "void*")
        }
    }
    
    static func determineRubyType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "Boolean", storageType: "Boolean", isPrimitive: true, initType: "Boolean")
        case is Int:
            return TypeInfo(type: "Integer", storageType: "Integer", isPrimitive: true, initType: "Integer")
        case is Double:
            return TypeInfo(type: "Float", storageType: "Float", isPrimitive: true, initType: "Float")
        case is String:
            return TypeInfo(type: "String", storageType: "String", isPrimitive: false, initType: "String")
        case let array as [Any]:
            return TypeInfo(type: "Array", storageType: "Array", isPrimitive: false, initType: "Array")
        case let dict as [String: Any]:
            return TypeInfo(type: "Hash", storageType: "Hash", isPrimitive: false, initType: "Hash")
        default:
            return TypeInfo(type: "Object", storageType: "Object", isPrimitive: false, initType: "Object")
        }
    }
    
    static func determineRustType(from value: Any) -> TypeInfo {
        switch value {
        case is Bool:
            return TypeInfo(type: "bool", storageType: "bool", isPrimitive: true, initType: "bool")
        case is Int:
            return TypeInfo(type: "i32", storageType: "i32", isPrimitive: true, initType: "i32")
        case is Double:
            return TypeInfo(type: "f64", storageType: "f64", isPrimitive: true, initType: "f64")
        case is String:
            return TypeInfo(type: "String", storageType: "String", isPrimitive: false, initType: "String")
        case let array as [Any]:
            if array.isEmpty {
                return TypeInfo(type: "Vec<Box<dyn std::any::Any>>", storageType: "Vec<Box<dyn std::any::Any>>", isPrimitive: false, initType: "Vec<Box<dyn std::any::Any>>")
            }
            let elementType = determineRustType(from: array[0])
            return TypeInfo(
                type: "Vec<\(elementType.type)>",
                storageType: "Vec<\(elementType.storageType)>",
                isPrimitive: false,
                initType: "Vec<\(elementType.initType)>"
            )
        case let dict as [String: Any]:
            return TypeInfo(type: "std::collections::HashMap<String, Box<dyn std::any::Any>>", storageType: "std::collections::HashMap<String, Box<dyn std::any::Any>>", isPrimitive: false, initType: "std::collections::HashMap<String, Box<dyn std::any::Any>>")
        default:
            return TypeInfo(type: "Box<dyn std::any::Any>", storageType: "Box<dyn std::any::Any>", isPrimitive: false, initType: "Box<dyn std::any::Any>")
        }
    }
}

