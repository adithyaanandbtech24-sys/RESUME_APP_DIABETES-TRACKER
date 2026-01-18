// MedicalAbbreviationParser.swift
// Parser for medical abbreviations commonly found in handwritten prescriptions

import Foundation

/// Parser for expanding medical abbreviations in prescriptions
final class MedicalAbbreviationParser {
    
    // MARK: - Frequency Abbreviations
    
    private static let frequencyAbbreviations: [String: String] = [
        // Latin-based frequency terms
        "od": "Once daily",
        "qd": "Once daily",
        "qid": "Four times daily",
        "qhs": "At bedtime",
        "q.d.": "Once daily",
        "q.i.d.": "Four times daily",
        "q.h.s.": "At bedtime",
        
        "bd": "Twice daily",
        "bid": "Twice daily",
        "b.i.d.": "Twice daily",
        "b.d.": "Twice daily",
        "1-0-1": "Twice daily (morning and night)",
        
        
        "tds": "Three times daily",
        "tid": "Three times daily",
        "t.i.d.": "Three times daily",
        "t.d.s.": "Three times daily",
        "1-1-1": "Three times daily",
        
        "1-1-1-1": "Four times daily",
        
        "prn": "As needed",
        "p.r.n.": "As needed",
        "sos": "If needed",
        "s.o.s.": "If needed",
        
        "stat": "Immediately",
        "q4h": "Every 4 hours",
        "q6h": "Every 6 hours",
        "q8h": "Every 8 hours",
        "q12h": "Every 12 hours",
        "q.4.h.": "Every 4 hours",
        "q.6.h.": "Every 6 hours",
        "q.8.h.": "Every 8 hours",
        "q.12.h.": "Every 12 hours",
        
        // Weekly
        "qw": "Once weekly",
        "biw": "Twice weekly",
        "tiw": "Three times weekly",
        "qow": "Every other week",
        
        // Time of day
        "am": "In the morning",
        "pm": "In the evening",
        "mane": "In the morning",
        "nocte": "At night",
        "hs": "At bedtime",
        "h.s.": "At bedtime",
    ]
    
    // MARK: - Meal-Related Abbreviations
    
    private static let mealAbbreviations: [String: String] = [
        "ac": "Before meals",
        "a.c.": "Before meals",
        "pc": "After meals",
        "p.c.": "After meals",
        "cc": "With meals",
        "c.c.": "With meals",
        
        "bf": "Before food",
        "af": "After food",
        "wf": "With food",
        "ef": "Empty stomach",
        
        "ante cibum": "Before meals",
        "post cibum": "After meals",
        
        // Specific meals
        "a/f": "After food",
        "b/f": "Before food",
        "breakfast": "With breakfast",
        "lunch": "With lunch",
        "dinner": "With dinner",
    ]
    
    // MARK: - Route Abbreviations
    
    private static let routeAbbreviations: [String: String] = [
        "po": "By mouth (oral)",
        "p.o.": "By mouth (oral)",
        "oral": "By mouth",
        
        "sl": "Under the tongue (sublingual)",
        "s.l.": "Under the tongue (sublingual)",
        
        "iv": "Intravenous",
        "i.v.": "Intravenous",
        
        "im": "Intramuscular",
        "i.m.": "Intramuscular",
        
        "sc": "Subcutaneous",
        "s.c.": "Subcutaneous",
        "subq": "Subcutaneous",
        "s.q.": "Subcutaneous",
        
        "id": "Intradermal",
        "i.d.": "Intradermal",
        
        "pr": "Per rectum",
        "p.r.": "Per rectum",
        "rectal": "Per rectum",
        
        "pv": "Per vagina",
        "p.v.": "Per vagina",
        "vaginal": "Per vagina",
        
        "top": "Topical",
        "topical": "Apply to skin",
        "ext": "External use",
        "external": "External use only",
        
        "inh": "Inhaled",
        "neb": "Nebulization",
        "nasal": "Nasal",
        
        "op": "Eye drops",
        "o.p.": "Eye drops",
        "ophthalmic": "Eye drops",
        "os": "Left eye",
        "o.s.": "Left eye",
        "od": "Right eye (ophthalmic context)",
        "o.d.": "Right eye",
        "ou": "Both eyes",
        "o.u.": "Both eyes",
        
        "au": "Both ears",
        "a.u.": "Both ears",
        "as": "Left ear",
        "a.s.": "Left ear",
        "ad": "Right ear",
        "a.d.": "Right ear",
        "otic": "Ear drops",
    ]
    
    // MARK: - Dosage Form Abbreviations
    
    private static let dosageFormAbbreviations: [String: String] = [
        "tab": "Tablet",
        "tabs": "Tablets",
        "cap": "Capsule",
        "caps": "Capsules",
        "syr": "Syrup",
        "susp": "Suspension",
        "sol": "Solution",
        "soln": "Solution",
        "inj": "Injection",
        "amp": "Ampoule",
        "vial": "Vial",
        "supp": "Suppository",
        "oint": "Ointment",
        "crm": "Cream",
        "cream": "Cream",
        "lotion": "Lotion",
        "gel": "Gel",
        "drops": "Drops",
        "gtts": "Drops",
        "gtt": "Drop",
        "patch": "Transdermal patch",
        "inh": "Inhaler",
        "mdi": "Metered dose inhaler",
        "neb": "Nebulizer solution",
        "pdr": "Powder",
        "pwd": "Powder",
        "sachet": "Sachet",
        "granules": "Granules",
        "lozenges": "Lozenges",
        "spray": "Spray",
        "er": "Extended release",
        "sr": "Sustained release",
        "xr": "Extended release",
        "cr": "Controlled release",
        "mr": "Modified release",
        "la": "Long acting",
        "xl": "Extended release",
    ]
    
    // MARK: - Unit Abbreviations
    
    private static let unitAbbreviations: [String: String] = [
        "mg": "milligrams",
        "gm": "grams",
        "g": "grams",
        "mcg": "micrograms",
        "μg": "micrograms",
        "ug": "micrograms",
        "ml": "milliliters",
        "cc": "cubic centimeters (ml)",
        "l": "liters",
        "iu": "international units",
        "u": "units",
        "meq": "milliequivalents",
        "tsp": "teaspoon (5ml)",
        "tbsp": "tablespoon (15ml)",
        "%": "percent",
    ]
    
    // MARK: - Public Methods
    
    /// Expand frequency abbreviation to full text
    static func expandFrequency(_ abbreviation: String) -> String {
        let normalized = abbreviation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct match
        if let expanded = frequencyAbbreviations[normalized] {
            return expanded
        }
        
        // Check meal timing
        if let mealInfo = mealAbbreviations[normalized] {
            return mealInfo
        }
        
        // Try matching parts
        var result = abbreviation
        for (abbr, full) in frequencyAbbreviations {
            if normalized.contains(abbr) {
                result = result.replacingOccurrences(of: abbr, with: full, options: .caseInsensitive)
            }
        }
        for (abbr, full) in mealAbbreviations {
            if normalized.contains(abbr) {
                result = result.replacingOccurrences(of: abbr, with: full, options: .caseInsensitive)
            }
        }
        
        return result
    }
    
    /// Expand route abbreviation to full text
    static func expandRoute(_ abbreviation: String) -> String {
        let normalized = abbreviation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return routeAbbreviations[normalized] ?? abbreviation
    }
    
    /// Expand dosage form abbreviation
    static func expandDosageForm(_ abbreviation: String) -> String {
        let normalized = abbreviation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return dosageFormAbbreviations[normalized] ?? abbreviation
    }
    
    /// Expand all abbreviations in a given text
    static func expandAllAbbreviations(in text: String) -> String {
        var result = text
        
        // Process all abbreviation dictionaries
        let allAbbreviations = [
            frequencyAbbreviations,
            mealAbbreviations,
            routeAbbreviations,
            dosageFormAbbreviations,
            unitAbbreviations
        ]
        
        for dict in allAbbreviations {
            for (abbr, full) in dict {
                // Use word boundary matching to avoid partial replacements
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbr))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: full
                    )
                }
            }
        }
        
        return result
    }
    
    /// Parse a complete prescription instruction string
    static func parseInstruction(_ instruction: String) -> ParsedInstruction {
        let lowercased = instruction.lowercased()
        
        var dosage: String? = nil
        var frequency: String? = nil
        var route: String? = nil
        var duration: String? = nil
        var mealTiming: String? = nil
        
        // Extract dosage (e.g., "500mg", "1 tablet")
        let dosagePattern = #"(\d+\.?\d*)\s*(mg|g|ml|mcg|iu|tab|caps?|tablets?|capsules?)"#
        if let regex = try? NSRegularExpression(pattern: dosagePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
            if let range = Range(match.range, in: lowercased) {
                dosage = String(instruction[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Extract frequency
        for (abbr, full) in frequencyAbbreviations {
            if lowercased.contains(abbr) {
                frequency = full
                break
            }
        }
        
        // Extract meal timing
        for (abbr, full) in mealAbbreviations {
            if lowercased.contains(abbr) {
                mealTiming = full
                break
            }
        }
        
        // Extract route
        for (abbr, full) in routeAbbreviations {
            if lowercased.contains(abbr) {
                route = full
                break
            }
        }
        
        // Extract duration (e.g., "for 7 days", "x 14 days")
        let durationPattern = #"(?:for|x)\s*(\d+)\s*(days?|weeks?|months?)"#
        if let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
            if let range = Range(match.range, in: lowercased) {
                duration = String(instruction[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return ParsedInstruction(
            dosage: dosage,
            frequency: frequency,
            route: route,
            duration: duration,
            mealTiming: mealTiming,
            original: instruction
        )
    }
}

// MARK: - Supporting Types

struct ParsedInstruction {
    let dosage: String?
    let frequency: String?
    let route: String?
    let duration: String?
    let mealTiming: String?
    let original: String
    
    var humanReadable: String {
        var parts: [String] = []
        
        if let d = dosage { parts.append(d) }
        if let f = frequency { parts.append(f) }
        if let r = route { parts.append(r) }
        if let m = mealTiming { parts.append(m) }
        if let dur = duration { parts.append(dur) }
        
        return parts.isEmpty ? original : parts.joined(separator: ", ")
    }
}
