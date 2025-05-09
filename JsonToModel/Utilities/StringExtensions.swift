//
//  StringExtensions.swift
//  JsonToModel
//
//  Created by 韩增超 on 2025/4/22.
//

import Foundation

extension String {
    func uppercasedFirstLetter() -> String {
        prefix(1).capitalized + dropFirst()
    }
    
    func lowercasedFirstLetter() -> String {
        prefix(1).lowercased() + dropFirst()
    }
    
    func toCamelCase() -> String {
        let parts = components(separatedBy: CharacterSet.alphanumerics.inverted)
        return parts.enumerated().map { index, part in
            index == 0 ? part.lowercased() : part.uppercasedFirstLetter()
        }.joined()
    }
    
    func camelCaseToSnakeCase() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: count)
        return regex?
            .stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
            .lowercased() ?? lowercased()
    }
}
