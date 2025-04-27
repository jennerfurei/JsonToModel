//
//  TypeUtilities.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

struct TypeUtilities {
    // MARK: - Swift Type Detection
    static func determineSwiftType(from value: Any) -> (type: String, initType: String) {
        // Handle dictionaries
        if let _ = value as? [String: Any] {
            return ("[String: Any]", "[String: Any]")
        }
        
        // Handle arrays
        if let arrayValue = value as? [Any], !arrayValue.isEmpty {
            let firstElement = arrayValue[0]
            
            if let _ = firstElement as? String {
                return ("[String]", "[String]")
            } else if let num = firstElement as? NSNumber {
                if CFGetTypeID(num) == CFBooleanGetTypeID() {
                    return ("[Bool]", "[Bool]")
                } else {
                    return isNumberInteger(num) ? ("[Int]", "[Int]") : ("[Double]", "[Double]")
                }
            } else if let _ = firstElement as? [String: Any] {
                return ("[[String: Any]]", "[[String: Any]]")
            } else {
                return ("[Any]", "[Any] = []")
            }
        }
        
        // Handle primitive types
        switch value {
        case is String:
            return ("String", "String")
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return ("Bool", "Bool")
            } else {
                return isNumberInteger(number) ? ("Int", "Int") : ("Double", "Double")
            }
        default:
            return ("Any", "Any?")
        }
    }
    
    // MARK: - Objective-C Type Detection
    static func determineObjCType(from value: Any) -> (type: String, storageType: String, isPrimitive: Bool) {
        // Handle dictionaries
        if let _ = value as? [String: Any] {
            return ("NSDictionary", "NSDictionary *", false)
        }
        
        // Handle arrays
        if let arrayValue = value as? [Any], !arrayValue.isEmpty {
            let firstElement = arrayValue[0]
            
            if let _ = firstElement as? String {
                return ("NSArray<NSString *>", "NSArray<NSString *> *", false)
            } else if let num = firstElement as? NSNumber {
                if CFGetTypeID(num) == CFBooleanGetTypeID() {
                    return ("NSArray<NSNumber *>", "NSArray<NSNumber *> *", false)
                } else {
                    return ("NSArray<NSNumber *>", "NSArray<NSNumber *> *", false)
                }
            } else if let _ = firstElement as? [String: Any] {
                return ("NSArray<NSDictionary *>", "NSArray<NSDictionary *> *", false)
            } else {
                return ("NSArray", "NSArray *", false)
            }
        }
        
        // Handle primitive types
        switch value {
        case is String:
            return ("NSString", "NSString *", false)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return ("BOOL", "BOOL", true)
            } else {
                return isNumberInteger(number) ?
                    ("NSInteger", "NSInteger", true) :
                    ("double", "double", true)
            }
        default:
            return ("id", "id", false)
        }
    }
    
    // MARK: - Number Type Detection
    private static func isNumberInteger(_ number: NSNumber) -> Bool {
        // Check if the number is a boolean first
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return false
        }
        
        // Get the Objective-C type encoding
        let objCType = String(cString: number.objCType)
        
        // Check for integer types
        if objCType.contains("i") || objCType.contains("l") || objCType.contains("q") {
            return true
        }
        
        // Check if the double value is actually an integer
        let doubleValue = number.doubleValue
        return doubleValue.truncatingRemainder(dividingBy: 1) == 0
    }
}
