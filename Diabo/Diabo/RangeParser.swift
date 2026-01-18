import Foundation

/// Helper structure to handle parsing of medical reference ranges
struct RangeParser {
    
    /// Result of a range parsing operation
    struct RangeBounds {
        let min: Double?
        let max: Double?
        
        var isValid: Bool {
            return min != nil || max != nil
        }
    }
    
    /// Parse a reference range string into numeric bounds
    /// Handles formats like:
    /// - "3.5 - 5.0"
    /// - "13.5-17.5"
    /// - "< 200"
    /// - "> 40"
    /// - "upto 150"
    /// - "0.0 - 0.9"
    static func parse(_ rangeString: String) -> RangeBounds {
        let cleanString = rangeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "–", with: "-") // Replace en-dash with hyphen
        
        if cleanString.isEmpty {
            return RangeBounds(min: nil, max: nil)
        }
        
        // Format: "< 5.7" or "upto 5.7" (Upper bound only)
        if cleanString.hasPrefix("<") || cleanString.contains("upto") || cleanString.contains("up to") {
            let numberString = cleanString
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: "upto", with: "")
                .replacingOccurrences(of: "up to", with: "")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if let max = Double(numberString) {
                // Determine reasonable min based on max (usually 0 for most biological values)
                return RangeBounds(min: 0.0, max: max)
            }
        }
        
        // Format: "> 60" (Lower bound only)
        if cleanString.hasPrefix(">") {
            let numberString = cleanString
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if let min = Double(numberString) {
                // Max is undefined, but for graphing we might cap it dynamically
                return RangeBounds(min: min, max: nil)
            }
        }
        
        // Format: "13.5 - 17.5" (Standard Range)
        if cleanString.contains("-") {
            let components = cleanString.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2, 
               let min = Double(components[0]), 
               let max = Double(components[1]) {
                return RangeBounds(min: min, max: max)
            }
        }
        
        // Fallback: Try regex for two distinct numbers
        // This catches cases like "13.5 to 17.5"
        do {
            let pattern = "([0-9.]+).*?([0-9.]+)"
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = cleanString as NSString
            if let match = regex.firstMatch(in: cleanString, range: NSRange(location: 0, length: nsString.length)) {
                if match.numberOfRanges >= 3,
                   let min = Double(nsString.substring(with: match.range(at: 1))),
                   let max = Double(nsString.substring(with: match.range(at: 2))) {
                    return RangeBounds(min: min, max: max)
                }
            }
        } catch {
            print("Regex error in RangeParser: \(error)")
        }
        
        return RangeBounds(min: nil, max: nil)
    }
}
