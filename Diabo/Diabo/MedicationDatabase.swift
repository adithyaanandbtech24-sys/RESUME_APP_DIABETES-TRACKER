// MedicationDatabase.swift
// Comprehensive medication database with fuzzy matching for prescription validation

import Foundation

/// Represents a medication in the database
struct MedicationEntry {
    let name: String
    let aliases: [String]
    let drugClass: String
    let commonDosages: [String]
    let isAntidiabetic: Bool
}

/// Medication database with fuzzy string matching for handwriting recognition validation
final class MedicationDatabase {
    static let shared = MedicationDatabase()
    
    private let medications: [MedicationEntry]
    
    private init() {
        medications = Self.buildMedicationDatabase()
    }
    
    // MARK: - Fuzzy Matching
    
    struct MatchResult {
        let name: String
        let drugClass: String
        let score: Double // 0.0 to 1.0
    }
    
    /// Find the best matching medication using fuzzy string matching
    func findBestMatch(for query: String) -> MatchResult? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard normalizedQuery.count >= 3 else { return nil }
        
        var bestMatch: (MedicationEntry, Double)? = nil
        
        for med in medications {
            // Check exact name match
            if med.name.lowercased() == normalizedQuery {
                return MatchResult(name: med.name, drugClass: med.drugClass, score: 1.0)
            }
            
            // Check aliases
            for alias in med.aliases {
                if alias.lowercased() == normalizedQuery {
                    return MatchResult(name: med.name, drugClass: med.drugClass, score: 1.0)
                }
            }
            
            // Fuzzy match on name
            let nameScore = Self.levenshteinSimilarity(normalizedQuery, med.name.lowercased())
            if nameScore > 0.7 {
                if bestMatch == nil || nameScore > bestMatch!.1 {
                    bestMatch = (med, nameScore)
                }
            }
            
            // Fuzzy match on aliases
            for alias in med.aliases {
                let aliasScore = Self.levenshteinSimilarity(normalizedQuery, alias.lowercased())
                if aliasScore > 0.7 {
                    if bestMatch == nil || aliasScore > bestMatch!.1 {
                        bestMatch = (med, aliasScore)
                    }
                }
            }
            
            // Check if query contains the medication name (for partial matches)
            if normalizedQuery.contains(med.name.lowercased().prefix(5)) && med.name.count > 4 {
                let containsScore = 0.75
                if bestMatch == nil || containsScore > bestMatch!.1 {
                    bestMatch = (med, containsScore)
                }
            }
        }
        
        if let match = bestMatch {
            return MatchResult(name: match.0.name, drugClass: match.0.drugClass, score: match.1)
        }
        
        return nil
    }
    
    /// Get all medication names (for fallback parsing)
    func getAllMedications() -> [String] {
        return medications.map { $0.name }
    }
    
    /// Get diabetes-related medications
    func getAntidiabeticMedications() -> [MedicationEntry] {
        return medications.filter { $0.isAntidiabetic }
    }
    
    // MARK: - Levenshtein Distance
    
    /// Calculate similarity between two strings (0.0 to 1.0)
    private static func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculate Levenshtein edit distance between two strings
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Medication Database
    
    private static func buildMedicationDatabase() -> [MedicationEntry] {
        return [
            // ========== ANTIDIABETIC MEDICATIONS ==========
            MedicationEntry(
                name: "Metformin",
                aliases: ["Glucophage", "Glycomet", "Glyciphage", "Obimet", "Metf", "Met"],
                drugClass: "Biguanide",
                commonDosages: ["500mg", "850mg", "1000mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Glimepiride",
                aliases: ["Amaryl", "Glimisave", "Zoryl", "Glim"],
                drugClass: "Sulfonylurea",
                commonDosages: ["1mg", "2mg", "3mg", "4mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Glipizide",
                aliases: ["Glucotrol", "Glipizip"],
                drugClass: "Sulfonylurea",
                commonDosages: ["2.5mg", "5mg", "10mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Gliclazide",
                aliases: ["Diamicron", "Glizid", "Glycin"],
                drugClass: "Sulfonylurea",
                commonDosages: ["40mg", "80mg", "30mg MR", "60mg MR"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Sitagliptin",
                aliases: ["Januvia", "Zita", "Sitared"],
                drugClass: "DPP-4 Inhibitor",
                commonDosages: ["25mg", "50mg", "100mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Vildagliptin",
                aliases: ["Galvus", "Zomelis", "Vysov"],
                drugClass: "DPP-4 Inhibitor",
                commonDosages: ["50mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Linagliptin",
                aliases: ["Trajenta", "Linares"],
                drugClass: "DPP-4 Inhibitor",
                commonDosages: ["5mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Empagliflozin",
                aliases: ["Jardiance", "Gibtulio", "Empa"],
                drugClass: "SGLT2 Inhibitor",
                commonDosages: ["10mg", "25mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Dapagliflozin",
                aliases: ["Forxiga", "Farxiga", "Dapa"],
                drugClass: "SGLT2 Inhibitor",
                commonDosages: ["5mg", "10mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Canagliflozin",
                aliases: ["Invokana", "Sulisent"],
                drugClass: "SGLT2 Inhibitor",
                commonDosages: ["100mg", "300mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Pioglitazone",
                aliases: ["Actos", "Pioz", "Piozone"],
                drugClass: "Thiazolidinedione",
                commonDosages: ["15mg", "30mg", "45mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Insulin Glargine",
                aliases: ["Lantus", "Basaglar", "Toujeo", "Semglee"],
                drugClass: "Long-acting Insulin",
                commonDosages: ["100 IU/ml", "300 IU/ml"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Insulin Aspart",
                aliases: ["NovoRapid", "NovoLog", "Fiasp"],
                drugClass: "Rapid-acting Insulin",
                commonDosages: ["100 IU/ml"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Insulin Lispro",
                aliases: ["Humalog", "Admelog", "Lyumjev"],
                drugClass: "Rapid-acting Insulin",
                commonDosages: ["100 IU/ml", "200 IU/ml"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Insulin NPH",
                aliases: ["Humulin N", "Novolin N", "Insulatard"],
                drugClass: "Intermediate-acting Insulin",
                commonDosages: ["100 IU/ml"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Semaglutide",
                aliases: ["Ozempic", "Rybelsus", "Wegovy"],
                drugClass: "GLP-1 Receptor Agonist",
                commonDosages: ["0.25mg", "0.5mg", "1mg", "2mg", "3mg", "7mg", "14mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Liraglutide",
                aliases: ["Victoza", "Saxenda"],
                drugClass: "GLP-1 Receptor Agonist",
                commonDosages: ["0.6mg", "1.2mg", "1.8mg"],
                isAntidiabetic: true
            ),
            MedicationEntry(
                name: "Dulaglutide",
                aliases: ["Trulicity"],
                drugClass: "GLP-1 Receptor Agonist",
                commonDosages: ["0.75mg", "1.5mg", "3mg", "4.5mg"],
                isAntidiabetic: true
            ),
            
            // ========== CARDIOVASCULAR ==========
            MedicationEntry(
                name: "Amlodipine",
                aliases: ["Norvasc", "Amlo", "Amlong", "Amlodac"],
                drugClass: "Calcium Channel Blocker",
                commonDosages: ["2.5mg", "5mg", "10mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Atenolol",
                aliases: ["Tenormin", "Aten", "Betacard"],
                drugClass: "Beta Blocker",
                commonDosages: ["25mg", "50mg", "100mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Metoprolol",
                aliases: ["Lopressor", "Betaloc", "Metolar", "Met XL"],
                drugClass: "Beta Blocker",
                commonDosages: ["25mg", "50mg", "100mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Lisinopril",
                aliases: ["Zestril", "Prinivil", "Listril"],
                drugClass: "ACE Inhibitor",
                commonDosages: ["2.5mg", "5mg", "10mg", "20mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Ramipril",
                aliases: ["Altace", "Cardace", "Ramipres"],
                drugClass: "ACE Inhibitor",
                commonDosages: ["2.5mg", "5mg", "10mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Losartan",
                aliases: ["Cozaar", "Losacar", "Losar"],
                drugClass: "ARB",
                commonDosages: ["25mg", "50mg", "100mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Telmisartan",
                aliases: ["Micardis", "Telma", "Telmikind"],
                drugClass: "ARB",
                commonDosages: ["20mg", "40mg", "80mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Atorvastatin",
                aliases: ["Lipitor", "Atorva", "Storvas", "Aztor"],
                drugClass: "Statin",
                commonDosages: ["10mg", "20mg", "40mg", "80mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Rosuvastatin",
                aliases: ["Crestor", "Rosuvas", "Rozavel"],
                drugClass: "Statin",
                commonDosages: ["5mg", "10mg", "20mg", "40mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Aspirin",
                aliases: ["Ecosprin", "Disprin", "ASA", "Asprin"],
                drugClass: "Antiplatelet",
                commonDosages: ["75mg", "81mg", "150mg", "325mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Clopidogrel",
                aliases: ["Plavix", "Clopilet", "Clopivas"],
                drugClass: "Antiplatelet",
                commonDosages: ["75mg", "150mg"],
                isAntidiabetic: false
            ),
            
            // ========== ANALGESICS / NSAIDS ==========
            MedicationEntry(
                name: "Paracetamol",
                aliases: ["Acetaminophen", "Tylenol", "Dolo", "Crocin", "P", "PCM"],
                drugClass: "Analgesic",
                commonDosages: ["500mg", "650mg", "1000mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Ibuprofen",
                aliases: ["Brufen", "Advil", "Motrin"],
                drugClass: "NSAID",
                commonDosages: ["200mg", "400mg", "600mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Diclofenac",
                aliases: ["Voltaren", "Voveran", "Diclo"],
                drugClass: "NSAID",
                commonDosages: ["50mg", "75mg", "100mg"],
                isAntidiabetic: false
            ),
            
            // ========== GI / ANTACIDS ==========
            MedicationEntry(
                name: "Pantoprazole",
                aliases: ["Protonix", "Pan", "Pantop", "Pan-D"],
                drugClass: "PPI",
                commonDosages: ["20mg", "40mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Omeprazole",
                aliases: ["Prilosec", "Omez", "Ocid"],
                drugClass: "PPI",
                commonDosages: ["20mg", "40mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Rabeprazole",
                aliases: ["Aciphex", "Rablet", "Razo"],
                drugClass: "PPI",
                commonDosages: ["10mg", "20mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Domperidone",
                aliases: ["Motilium", "Domstal", "Vomistop"],
                drugClass: "Prokinetic",
                commonDosages: ["10mg"],
                isAntidiabetic: false
            ),
            
            // ========== ANTIBIOTICS ==========
            MedicationEntry(
                name: "Amoxicillin",
                aliases: ["Amoxil", "Mox", "Novamox"],
                drugClass: "Antibiotic",
                commonDosages: ["250mg", "500mg", "875mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Azithromycin",
                aliases: ["Zithromax", "Azee", "Azithral"],
                drugClass: "Antibiotic",
                commonDosages: ["250mg", "500mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Ciprofloxacin",
                aliases: ["Cipro", "Ciplox", "Cifran"],
                drugClass: "Antibiotic",
                commonDosages: ["250mg", "500mg", "750mg"],
                isAntidiabetic: false
            ),
            
            // ========== VITAMINS & SUPPLEMENTS ==========
            MedicationEntry(
                name: "Vitamin D3",
                aliases: ["Cholecalciferol", "D3", "Calcirol", "Uprise"],
                drugClass: "Vitamin",
                commonDosages: ["1000 IU", "2000 IU", "60000 IU"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Vitamin B12",
                aliases: ["Methylcobalamin", "B12", "Mecobalamin", "Nervijen"],
                drugClass: "Vitamin",
                commonDosages: ["500mcg", "1500mcg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Folic Acid",
                aliases: ["Folate", "Folvite"],
                drugClass: "Vitamin",
                commonDosages: ["5mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Iron",
                aliases: ["Ferrous Sulfate", "Ferrous Fumarate", "Fefol", "Autrin"],
                drugClass: "Mineral Supplement",
                commonDosages: ["100mg", "200mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Calcium",
                aliases: ["Calcium Carbonate", "Shelcal", "Calcimax"],
                drugClass: "Mineral Supplement",
                commonDosages: ["500mg", "1000mg"],
                isAntidiabetic: false
            ),
            
            // ========== THYROID ==========
            MedicationEntry(
                name: "Levothyroxine",
                aliases: ["Synthroid", "Eltroxin", "Thyronorm", "Thyrox"],
                drugClass: "Thyroid Hormone",
                commonDosages: ["25mcg", "50mcg", "75mcg", "100mcg", "125mcg"],
                isAntidiabetic: false
            ),
            
            // ========== ANTIHISTAMINES ==========
            MedicationEntry(
                name: "Cetirizine",
                aliases: ["Zyrtec", "Cetzine", "Alerid"],
                drugClass: "Antihistamine",
                commonDosages: ["5mg", "10mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Levocetirizine",
                aliases: ["Xyzal", "Levocet", "Lezyncet"],
                drugClass: "Antihistamine",
                commonDosages: ["5mg"],
                isAntidiabetic: false
            ),
            MedicationEntry(
                name: "Montelukast",
                aliases: ["Singulair", "Montair", "Montek"],
                drugClass: "Leukotriene Inhibitor",
                commonDosages: ["4mg", "5mg", "10mg"],
                isAntidiabetic: false
            ),
        ]
    }
}
