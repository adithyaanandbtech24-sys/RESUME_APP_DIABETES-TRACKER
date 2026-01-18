// ChatService.swift
import Foundation
import SwiftData

/// Service for AI chatbot functionality (Refactored for local-first)
@MainActor
final class ChatService {
    static let shared = ChatService()
    
    private let auth = FirebaseAuthService.shared
    
    // MARK: - Ollama Configuration
    private let ollamaBaseURL = "http://localhost:11434"
    private let ollamaModel = "llama3.1:8b"  // Best for medical chatbot (4.9GB)
    
    // MARK: - Fallback to OpenRouter if Ollama unavailable
    private let useOllamaFirst = true  // Enable once model downloaded
    private let openRouterKey = "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"
    
    // MARK: - Professional System Prompt (No emojis, No markdown)
    private let medisyncSystemPrompt = """
    You are MediSync Chatbot, a professional, concise, and factual conversational assistant running locally.

    Your sole purpose is to generate clear, structured, professional summaries and responses for user queries inside the MediSync application.

    You do not use emojis.
    You do not use special symbols, bullet characters, markdown decorations, or stylistic formatting.
    You do not use a conversational or casual tone.
    You do not include disclaimers unless explicitly requested.
    You do not provide medical diagnosis or treatment recommendations.

    All responses must be professional in tone, concise and direct, written in plain sentences and short paragraphs, focused on key facts and important points only, and free of filler language or casual phrasing.

    You may respond to health-related questions in an explanatory and educational manner, report summaries when text is provided, clarifications about medical terms or values, and high-level interpretations without diagnosis.

    You must refuse or reframe requests for diagnosis, requests for treatment plans, and emergency or critical care instructions.

    When summarizing information, start with a brief overview sentence, follow with grouped key points in paragraph form, and end with a short concluding sentence if appropriate.

    When answering questions, answer directly, provide only relevant context, and avoid speculation or assumptions.

    Use only the information explicitly provided by the user. Do not invent missing data. If information is insufficient, state that clearly and stop. Do not ask follow-up questions unless required for clarity.

    If a request cannot be fulfilled, state the limitation clearly, provide the closest safe alternative explanation, and keep the response brief and professional.

    The final output must be plain text only with no emojis, no bullet symbols, no markdown, and no decorative formatting.
    """
    
    func sendMessageToAI(
        message: String,
        context: ModelContext,
        medicalContext: [String: Any]? = nil
    ) async throws -> String {
        print("[ChatService] Processing message: \(message)")
        
        // 1. Save user message IMMEDIATELY so UI updates
        let userMessage = AIChatMessage(text: message, isUser: true)
        context.insert(userMessage)
        try? context.save()
        
        // 2. Simple greeting handler
        if message.lowercased() == "hi" || message.lowercased() == "hello" {
            let greeting = "Hello. I am MediSync Chatbot, your health information assistant. I can help explain your lab results, track your vitals, or answer questions about your health data. How can I assist you today?"
            let aiMessage = AIChatMessage(text: greeting, isUser: false)
            context.insert(aiMessage)
            try? context.save()
            return greeting
        }
        
        // 3. Try Ollama first, fallback to OpenRouter
        do {
            if useOllamaFirst {
                let result = try await sendToOllama(message: message, context: context)
                saveAIResponse(text: result, context: context)
                return result
            }
        } catch {
            print("[ChatService] Ollama failed: \(error). Trying OpenRouter fallback...")
        }
        
        // 4. OpenRouter fallback
        do {
            let result = try await sendToOpenRouter(message: message, context: context)
            saveAIResponse(text: result, context: context)
            return result
        } catch let error as URLError {
            print("[ChatService] All API calls failed: \(error)")
            let fallback: String
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                fallback = "You appear to be offline. Please check your internet connection and try again."
            case .timedOut:
                fallback = "The request timed out. The AI service may be experiencing high demand. Please try again in a moment."
            default:
                fallback = "Unable to connect to the AI service at this time. Please check your connection and try again."
            }
            saveAIResponse(text: fallback, context: context)
            return fallback
        } catch {
            print("[ChatService] Unexpected error: \(error)")
            let fallback = "An unexpected error occurred. Please try again."
            saveAIResponse(text: fallback, context: context)
            return fallback
        }
    }
    
    // MARK: - Ollama HTTP API
    private func sendToOllama(message: String, context: ModelContext) async throws -> String {
        let graphContext = GraphRAGEngine.shared.retrieveContext(for: message, context: context)
        
        let url = URL(string: "\(ollamaBaseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Longer timeout for local inference
        
        let fullPrompt = """
        \(medisyncSystemPrompt)

        Medical Context:
        \(graphContext.isEmpty ? "No specific medical history available." : graphContext)

        User Query:
        \(message)
        """
        
        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": fullPrompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 500
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[ChatService] Sending request to Ollama...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[ChatService] Ollama response status: \(httpResponse.statusCode)")
            if !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        print("[ChatService] Ollama response received: \(responseText.prefix(100))...")
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - OpenRouter Fallback
    private func sendToOpenRouter(message: String, context: ModelContext) async throws -> String {
        let graphContext = GraphRAGEngine.shared.retrieveContext(for: message, context: context)
        
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MediSync App", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 45
        
        let body: [String: Any] = [
            "model": "google/gemini-2.0-flash-001",
            "messages": [
                ["role": "system", "content": medisyncSystemPrompt + "\n\nMedical Context:\n\(graphContext.isEmpty ? "No specific medical history available." : graphContext)"],
                ["role": "user", "content": message]
            ],
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let text = messageObj["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return text
    }
    
    private func saveAIResponse(text: String, context: ModelContext) {
        let aiMessage = AIChatMessage(text: text, isUser: false)
        context.insert(aiMessage)
        try? context.save()
    }
    
    private func generateSimulatedChatResponse(for message: String) -> String {
        return "I'm having trouble connecting to the server. Please check your internet connection and try again."
    }
    
    // MARK: - Report Interpretation (Comprehensive Professional Summary)
    /// Generates a comprehensive professional interpretation of uploaded medical reports
    /// Uses local Ollama model for privacy-first analysis
    func generateReportInterpretation(
        extractedText: String,
        labResults: [LabResultModel],
        userProfile: UserProfileModel?
    ) async throws -> String {
        print("[ChatService] Generating comprehensive report interpretation...")
        
        // Build user context
        var patientContext = "Patient profile not available."
        if let profile = userProfile {
            var bmi = "Unknown"
            if let h = profile.height, let w = profile.weight, h > 0 {
                let heightM = h / 100.0
                bmi = String(format: "%.1f", w / (heightM * heightM))
            }
            patientContext = """
            Patient Profile:
            Name: \(profile.name)
            Age: \(profile.age) years
            Gender: \(profile.gender.capitalized)
            Height: \(profile.height ?? 0) cm
            Weight: \(profile.weight ?? 0) kg
            BMI: \(bmi)
            Diabetes Type: \(profile.diabetesType)
            Treatment: \(profile.treatmentType)
            Comorbidities: \(profile.comorbidities.isEmpty ? "None reported" : profile.comorbidities.joined(separator: ", "))
            """
        }
        
        // Build lab results summary
        var labSummary = "No lab results extracted."
        if !labResults.isEmpty {
            let labLines = labResults.map { result in
                let status = result.status.isEmpty ? "Unknown" : result.status
                let range = result.normalRange.isEmpty ? "Range not specified" : result.normalRange
                return "- \(result.testName): \(result.value) \(result.unit) (Normal: \(range)) - Status: \(status)"
            }
            labSummary = "Extracted Lab Results:\n" + labLines.joined(separator: "\n")
        }
        
        let interpretationPrompt = """
        You are a professional medical report interpreter for MediSync, a diabetes management application.

        Generate a comprehensive, professional interpretation of the following medical report. This interpretation will be shown to the patient immediately after they upload their report.

        IMPORTANT GUIDELINES:
        1. Write in plain text only. No emojis, no markdown, no bullet symbols, no special formatting.
        2. Use professional medical language but make it understandable for patients.
        3. Organize the interpretation into clear sections using paragraph breaks.
        4. Be thorough and cover all important findings.
        5. Highlight values that are outside normal ranges and explain what they mean.
        6. Consider the patient's profile when interpreting results.
        7. Do not diagnose or prescribe treatment. Focus on explaining findings.
        8. End with a recommendation to discuss findings with their healthcare provider.

        STRUCTURE YOUR RESPONSE AS FOLLOWS:

        REPORT OVERVIEW
        Provide a brief summary of what type of report this is and when it was generated.

        KEY FINDINGS
        List and explain the most important findings from the report. For each abnormal value, explain what it means for the patient's health.

        ORGAN SYSTEM ANALYSIS
        Group findings by organ system (metabolism/diabetes, kidney function, liver function, lipid profile, blood counts, etc.) and explain how each system is functioning based on the results.

        DIABETES-SPECIFIC INSIGHTS
        Given that this is a diabetes management app, provide specific insights related to blood sugar control, HbA1c trends, and any diabetes-related markers.

        AREAS OF CONCERN
        Clearly state any values that are outside the normal range and require attention. Explain the potential implications.

        POSITIVE FINDINGS
        Acknowledge any values that are within normal range and indicate good health.

        RECOMMENDATIONS
        Suggest general health maintenance steps and remind the patient to discuss these findings with their healthcare provider.

        ---

        \(patientContext)

        ---

        \(labSummary)

        ---

        Raw Report Text (for additional context):
        \(extractedText.prefix(3000))
        """
        
        // Use Ollama for interpretation
        let url = URL(string: "\(ollamaBaseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes for comprehensive analysis
        
        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": interpretationPrompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 2000  // Allow longer responses for comprehensive interpretation
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[ChatService] Sending interpretation request to Ollama...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[ChatService] Ollama interpretation response status: \(httpResponse.statusCode)")
            if !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        print("[ChatService] Interpretation generated successfully (\(responseText.count) chars)")
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func analyzeMedicalText(_ text: String, userProfile: UserProfileModel? = nil) async throws -> MedicalAnalysisResult {
        print("[ChatService] Analyzing medical text with clinical-grade prompt...")
        
        // Ollama-first for OCR analysis as well
        if !useOllamaFirst && openRouterKey == "YOUR_API_KEY" {
             return generateSimulatedAnalysis()
        }
        
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Diabo App", forHTTPHeaderField: "X-Title")
        
        // Build user profile context
        var profileContext = "No user profile available."
        if let profile = userProfile {
            var bmi = "Unknown"
            if let h = profile.height, let w = profile.weight, h > 0 {
                let heightM = h / 100.0
                bmi = String(format: "%.1f", w / (heightM * heightM))
            }
            profileContext = """
            Patient Profile:
            - Age: \(profile.age) years
            - Gender: \(profile.gender)
            - Height: \(profile.height ?? 0) cm
            - Weight: \(profile.weight ?? 0) kg
            - BMI: \(bmi)
            - Diabetes Type: \(profile.diabetesType)
            - Treatment: \(profile.treatmentType)
            - Comorbidities: \(profile.comorbidities.joined(separator: ", "))
            """
        }
        
        let systemPrompt = """
        You are a clinical lab report analyzer for the Diabo diabetes management app.
        
        ## YOUR TASK
        Analyze the provided medical document text (OCR output from lab reports, prescriptions, Echo reports, or doctor notes).
        Extract ALL relevant information and return a structured JSON response.
        
        ## CRITICAL INSTRUCTIONS
        
        ### 1. EXTRACT REPORT DATES
        Find ALL dates mentioned (collection date, report date, test date). Use format "YYYY-MM-DD".
        Common date formats in Indian reports: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
        
        ### 2. IDENTIFY LAB SOURCE
        Extract the lab/hospital name from the header (e.g., "Medall", "Orange Health Labs", "Sreenidhi Diabetic Centre")
        
        ### 3. CATEGORIZE BY ORGAN SYSTEM
        Map EVERY test to the correct organ system:
        
        **Metabolism (Diabetes)**
        - FBS, Fasting Blood Sugar, Fasting Glucose
        - PPBS, Post Prandial Blood Sugar, Post Prandial Glucose
        - HbA1c, Glycated Hemoglobin, Glycosylated Hemoglobin
        - Random Blood Sugar, Mean Blood Glucose
        - OGTT, Oral Glucose Tolerance Test
        
        **Kidneys (Renal Function)**
        - Creatinine, Serum Creatinine
        - BUN, Blood Urea Nitrogen, Urea
        - eGFR, Estimated Glomerular Filtration Rate
        - Microalbumin, Urine Albumin
        - Uric Acid
        - BUN/Creatinine Ratio
        
        **Liver (Hepatic Function)**
        - SGOT, AST, Aspartate Aminotransferase
        - SGPT, ALT, Alanine Aminotransferase
        - Bilirubin (Total, Direct, Indirect)
        - ALP, Alkaline Phosphatase
        - GGT, Gamma GT
        - Albumin, Globulin, A:G Ratio
        - Total Protein
        
        **Heart (Cardiovascular)**
        - Total Cholesterol
        - LDL Cholesterol, LDL-C
        - HDL Cholesterol, HDL-C
        - VLDL Cholesterol
        - Triglycerides
        - Non-HDL Cholesterol
        - Cholesterol/HDL Ratio
        - Apolipoprotein A1, Apolipoprotein B
        - hsCRP, High Sensitivity CRP
        - Homocysteine
        - Lipoprotein(a)
        
        **Cardiac Imaging (Echo/ECG)**
        - Ejection Fraction, EF
        - Left Ventricle dimensions
        - Aorta, Left Atrium measurements
        - Valve assessments (Mitral, Aortic, Tricuspid, Pulmonary)
        - DOPPLER measurements
        
        **Blood (Hematology/CBC)**
        - Hemoglobin, Hb
        - RBC, Red Blood Cells, Erythrocytes
        - WBC, White Blood Cells, Leukocytes
        - Platelets, Platelet Count
        - PCV, Packed Cell Volume, Hematocrit
        - MCV, MCH, MCHC, RDW
        - ESR, Erythrocyte Sedimentation Rate
        - Neutrophils, Lymphocytes, Monocytes, Eosinophils, Basophils
        - Peripheral Smear findings
        
        **Thyroid**
        - TSH, Thyroid Stimulating Hormone
        - T3, Total T3, Free T3
        - T4, Total T4, Free T4
        
        **Vitamins & Minerals**
        - Vitamin D, 25-Hydroxy Vitamin D
        - Vitamin B12, Cyanocobalamin
        - Folic Acid, Folate
        - Ferritin, Iron, TIBC
        - Calcium, Phosphorus, Magnesium
        
        **Electrolytes**
        - Sodium, Na+
        - Potassium, K+
        - Chloride, Cl-
        
        **Hormones & Tumor Markers**
        - PSA, Prostate Specific Antigen
        - Cortisol
        - Testosterone, Estrogen, Progesterone
        
        **Urine Analysis**
        - Physical: Color, Appearance, Volume, Specific Gravity, pH
        - Chemical: Glucose, Protein, Ketone, Blood, Bilirubin, Urobilinogen, Nitrite, Leukocytes
        - Microscopic: Pus Cells, RBCs, Epithelial Cells, Casts, Crystals, Bacteria
        
        ### 4. DETERMINE STATUS
        Compare each value against the normal range provided in the document:
        - "Normal" if within range
        - "High" if above range
        - "Low" if below range
        - "Critical" if dangerously out of range (e.g., eGFR < 30, HbA1c > 10%, Potassium > 6)
        
        ### 5. EXTRACT MEDICATIONS
        If any medications/prescriptions are mentioned, extract:
        - Name (generic or brand)
        - Dosage (e.g., "500mg", "10 units")
        - Frequency (e.g., "twice daily", "before meals")
        - Instructions (e.g., "with food", "at bedtime")
        
        ### 6. GENERATE CLINICAL SUMMARY
        Write a professional clinical summary:
        - State the report date and source (lab name)
        - List key findings (abnormal values first)
        - Group findings by concern level
        - For diabetes: Comment on glycemic control based on HbA1c
        - NO medical advice, only objective observations
        
        ## USER PROFILE FOR PERSONALIZED INTERPRETATION
        \(profileContext)
        
        ## RESPONSE FORMAT (STRICT JSON)
        {
            "reportType": "Lab Report",
            "reportDate": "2025-01-11",
            "labSource": "Orange Health Labs",
            "summary": "Report dated 11-Jan-2025 from Orange Health Labs shows elevated glycemic markers with HbA1c at 10.2% indicating poor glycemic control. Kidney function markers (eGFR, Creatinine) are within normal limits. Electrolytes balanced.",
            "labResults": [
                {
                    "testName": "HbA1c",
                    "value": "10.2",
                    "unit": "%",
                    "normalRange": "< 5.7",
                    "status": "Critical",
                    "category": "Diabetes",
                    "organ": "Metabolism",
                    "testDate": "2025-01-11"
                },
                {
                    "testName": "Fasting Glucose",
                    "value": "208",
                    "unit": "mg/dL",
                    "normalRange": "70-99",
                    "status": "High",
                    "category": "Diabetes",
                    "organ": "Metabolism",
                    "testDate": "2025-01-11"
                }
            ],
            "medications": []
        }
        
        IMPORTANT: Return ONLY valid JSON. No markdown, no explanations, no code blocks.
        """
        
        let body: [String: Any] = [
            "model": "google/gemini-2.0-flash-001",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Analyze this medical document:\n\n\(text)"]
            ],
            "temperature": 0.1,
            "max_tokens": 16000
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let textResponse = choices.first?["message"] as? [String: Any],
               let content = textResponse["content"] as? String {
                
                print("📥 [ChatService] Received AI response, parsing JSON...")
                print("📥 [ChatService] RAW RESPONSE (first 2000 chars):")
                print(String(content.prefix(2000)))
                
                // Extract JSON from response (handle markdown code blocks)
                var jsonStr = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let start = jsonStr.firstIndex(of: "{"), let end = jsonStr.lastIndex(of: "}") {
                    jsonStr = String(jsonStr[start...end])
                }
                
                if let jsonData = jsonStr.data(using: .utf8) {
                    do {
                        let result = try JSONDecoder().decode(MedicalAnalysisResult.self, from: jsonData)
                        print("✅ [ChatService] Successfully parsed \(result.labResults.count) lab results and \(result.medications.count) medications")
                        
                        // Log each extracted lab result
                        for lab in result.labResults {
                            print("   📋 \(lab.testName): \(lab.value) \(lab.unit)")
                        }
                        
                        return result
                    } catch {
                        print("❌ [ChatService] JSON DECODE ERROR: \(error)")
                        print("❌ [ChatService] Falling back to local extraction...")
                    }
                }
            }
        } catch {
            print("❌ AI Analysis error: \(error)")
        }
        
        print("⚠️ [ChatService] Using LOCAL EXTRACTION (offline parsing)...")
        return extractLocalDataComprehensive(from: text)
    }
    
    private func extractLocalDataComprehensive(from text: String) -> MedicalAnalysisResult {
        let labModels = MedicalDataParser.parseLabResults(from: text)
        let foundLabs = labModels.map { model in
            LabResultDTO(
                testName: model.testName,
                value: String(format: "%.1f", model.value),
                unit: model.unit,
                status: model.status,
                category: model.category,
                organ: "General",
                normalRange: model.normalRange,
                testDate: nil
            )
        }
        
        return MedicalAnalysisResult(
            reportType: "Lab Report",
            reportDate: nil,
            labSource: nil,
            summary: "Extracted \(foundLabs.count) parameters.",
            labResults: foundLabs,
            medications: []
        )
    }

    private func generateSimulatedAnalysis() -> MedicalAnalysisResult {
        return MedicalAnalysisResult(
            reportType: "Lab Report",
            reportDate: nil,
            labSource: nil,
            summary: "Simulated analysis.",
            labResults: [],
            medications: []
        )
    }
    
    /// Generate a comprehensive professional clinical summary for the chatbot to display after upload
    func generateClinicalSummary(
        analysisResult: MedicalAnalysisResult,
        userProfile: UserProfileModel?
    ) -> String {
        var summary = ""
        
        // Count results by status
        let totalParams = analysisResult.labResults.count
        let criticalResults = analysisResult.labResults.filter { $0.status == "Critical" }
        let abnormalResults = analysisResult.labResults.filter { $0.status == "High" || $0.status == "Low" }
        let normalResults = analysisResult.labResults.filter { $0.status == "Normal" }
        
        // ===== INTRODUCTION =====
        summary += "MEDICAL REPORT ANALYSIS\n\n"
        
        if let date = analysisResult.reportDate, !date.isEmpty {
            if let source = analysisResult.labSource, !source.isEmpty {
                summary += "This is a comprehensive analysis of your medical report from \(source), dated \(date). "
            } else {
                summary += "This is a comprehensive analysis of your medical report dated \(date). "
            }
        } else {
            summary += "This is a comprehensive analysis of your submitted medical report. "
        }
        
        summary += "The report includes \(totalParams) laboratory parameters that have been evaluated to assess your overall health status and organ function.\n\n"
        
        // ===== EXECUTIVE SUMMARY =====
        summary += "SUMMARY OF FINDINGS\n\n"
        
        if criticalResults.isEmpty && abnormalResults.isEmpty {
            summary += "All \(totalParams) parameters analyzed in this report fall within their respective normal reference ranges. This is an encouraging finding that suggests your organ systems are functioning appropriately based on these laboratory markers. "
            summary += "While these results are reassuring, it is important to continue with regular health monitoring and maintain a healthy lifestyle.\n\n"
        } else {
            let abnormalTotal = criticalResults.count + abnormalResults.count
            summary += "Of the \(totalParams) parameters analyzed, \(normalResults.count) are within normal reference ranges, while \(abnormalTotal) require attention. "
            
            if !criticalResults.isEmpty {
                summary += "Notably, \(criticalResults.count) value(s) are significantly outside the expected range and warrant prompt medical evaluation. "
            }
            summary += "The detailed interpretation of each finding is provided below.\n\n"
        }
        
        // ===== CRITICAL FINDINGS =====
        if !criticalResults.isEmpty {
            summary += "CRITICAL FINDINGS REQUIRING IMMEDIATE ATTENTION\n\n"
            summary += "The following laboratory values are significantly outside their normal reference ranges. These findings may indicate conditions that require urgent medical evaluation:\n\n"
            
            for result in criticalResults {
                summary += "\(result.testName): Your result of \(result.value) \(result.unit) is outside the expected reference range of \(result.normalRange). "
                summary += "\(getDetailedExplanation(testName: result.testName, status: result.status, value: result.value))\n\n"
            }
        }
        
        // ===== ORGAN-BY-ORGAN DETAILED ANALYSIS =====
        let organGroups = Dictionary(grouping: analysisResult.labResults) { result -> String in
            let organ = (result.organ ?? result.category).lowercased()
            switch organ {
            case "metabolism", "diabetes", "glucose", "metabolic": return "Metabolic and Diabetes Markers"
            case "kidneys", "renal", "kidney": return "Kidney Function"
            case "liver", "hepatic": return "Liver Function"
            case "heart", "cardiovascular", "cardiac", "lipid": return "Cardiovascular and Lipid Profile"
            case "blood", "hematology", "cbc": return "Blood Cell Analysis"
            case "thyroid": return "Thyroid Function"
            case "vitamins", "vitamin", "minerals": return "Vitamins and Minerals"
            case "electrolytes": return "Electrolyte Balance"
            default: return "General Chemistry"
            }
        }
        
        let organOrder = ["Metabolic and Diabetes Markers", "Kidney Function", "Liver Function", "Cardiovascular and Lipid Profile", "Blood Cell Analysis", "Thyroid Function", "Vitamins and Minerals", "Electrolyte Balance", "General Chemistry"]
        
        summary += "DETAILED ORGAN SYSTEM ANALYSIS\n\n"
        
        for organName in organOrder {
            guard let results = organGroups[organName], !results.isEmpty else { continue }
            
            let organAbnormal = results.filter { $0.status != "Normal" }
            let organNormal = results.filter { $0.status == "Normal" }
            
            summary += "\(organName)\n\n"
            
            if organAbnormal.isEmpty {
                summary += "All \(results.count) parameters related to \(organName.lowercased()) are within normal limits. "
                summary += "This indicates that this organ system is functioning appropriately based on the available laboratory evidence. "
                let normalNames = organNormal.map { $0.testName }.joined(separator: ", ")
                summary += "The tests evaluated include: \(normalNames).\n\n"
            } else {
                // Describe abnormal findings in detail
                for result in organAbnormal {
                    let direction = result.status == "High" ? "elevated above" : "below"
                    summary += "\(result.testName): Your result is \(result.value) \(result.unit), which is \(direction) the normal reference range of \(result.normalRange). "
                    summary += "\(getDetailedExplanation(testName: result.testName, status: result.status, value: result.value))\n\n"
                }
                
                // Mention normal values in this category
                if !organNormal.isEmpty {
                    let normalNames = organNormal.map { $0.testName }.joined(separator: ", ")
                    summary += "The following parameters in this category are within normal limits: \(normalNames).\n\n"
                }
            }
        }
        
        // ===== DIABETES-SPECIFIC ANALYSIS =====
        let diabetesMarkers = analysisResult.labResults.filter { result in
            let name = result.testName.lowercased()
            return name.contains("hba1c") || name.contains("glucose") || name.contains("sugar") || 
                   name.contains("fasting") || name.contains("ppbs") || name.contains("insulin")
        }
        
        if !diabetesMarkers.isEmpty {
            summary += "DIABETES AND BLOOD SUGAR ASSESSMENT\n\n"
            
            if let hba1c = diabetesMarkers.first(where: { $0.testName.lowercased().contains("hba1c") }) {
                let value = Double(hba1c.value) ?? 0
                summary += "Your HbA1c (Glycated Hemoglobin) level is \(hba1c.value)%. This test reflects your average blood sugar control over the past two to three months. "
                
                if value < 5.7 {
                    summary += "Your result is within the normal range, indicating excellent long-term blood sugar control. This is a positive finding that suggests a low risk for diabetes at this time.\n\n"
                } else if value < 6.5 {
                    summary += "Your result falls in the prediabetes range (5.7-6.4%). This indicates that your blood sugar levels have been higher than optimal. Lifestyle modifications including dietary changes, regular physical activity, and weight management can help prevent progression to diabetes.\n\n"
                } else if value < 7.0 {
                    summary += "Your result indicates diabetes with reasonably good control. The American Diabetes Association recommends a target below 7% for most adults with diabetes. Continue following your current diabetes management plan and discuss with your healthcare provider whether any adjustments are needed.\n\n"
                } else if value < 8.0 {
                    summary += "Your result indicates suboptimal blood sugar control. HbA1c levels in this range are associated with an increased risk of diabetes complications over time. It would be advisable to discuss potential treatment adjustments with your healthcare provider.\n\n"
                } else {
                    summary += "Your result indicates poor blood sugar control which significantly increases the risk of serious complications including damage to the eyes, kidneys, nerves, and cardiovascular system. It is strongly recommended that you consult your healthcare provider as soon as possible to review and optimize your diabetes management.\n\n"
                }
            }
            
            let glucoseMarkers = diabetesMarkers.filter { !$0.testName.lowercased().contains("hba1c") }
            if !glucoseMarkers.isEmpty {
                summary += "Additional glucose measurements in this report:\n\n"
                for marker in glucoseMarkers {
                    summary += "\(marker.testName): \(marker.value) \(marker.unit). "
                    if marker.status == "Normal" {
                        summary += "This value is within the normal reference range.\n"
                    } else {
                        let direction = marker.status == "High" ? "elevated" : "low"
                        summary += "This value is \(direction), which \(marker.status == "High" ? "may indicate impaired glucose regulation or insufficient diabetes control" : "suggests hypoglycemia which requires attention").\n"
                    }
                }
                summary += "\n"
            }
        }
        
        // ===== MEDICATIONS =====
        if !analysisResult.medications.isEmpty {
            summary += "MEDICATIONS DOCUMENTED\n\n"
            summary += "The following medications were identified in your report:\n\n"
            for med in analysisResult.medications {
                summary += "- \(med.name)"
                if !med.dosage.isEmpty {
                    summary += " at a dosage of \(med.dosage)"
                }
                if !med.frequency.isEmpty {
                    summary += ", to be taken \(med.frequency)"
                }
                summary += "\n"
            }
            summary += "\nIt is important to take all medications exactly as prescribed and to discuss any concerns or side effects with your healthcare provider.\n\n"
        }
        
        // ===== CLINICAL RECOMMENDATIONS =====
        summary += "RECOMMENDATIONS\n\n"
        
        if !criticalResults.isEmpty {
            summary += "Given the presence of critical findings in this report, it is strongly recommended that you schedule an appointment with your healthcare provider at the earliest opportunity. Some findings may require immediate medical attention and should not be delayed.\n\n"
        } else if !abnormalResults.isEmpty {
            summary += "While none of your results are critically abnormal, several values warrant discussion with your healthcare provider. Consider scheduling a follow-up appointment to review these findings and determine if any additional testing or treatment adjustments are needed.\n\n"
        }
        
        summary += "General health recommendations based on your results:\n\n"
        summary += "1. Continue regular health monitoring with periodic laboratory testing as recommended by your healthcare provider.\n\n"
        summary += "2. Maintain a balanced diet rich in vegetables, fruits, whole grains, and lean proteins while limiting processed foods, excessive salt, and added sugars.\n\n"
        summary += "3. Engage in regular physical activity appropriate for your age and health status, aiming for at least 150 minutes of moderate exercise per week.\n\n"
        summary += "4. Stay adequately hydrated and ensure sufficient sleep for optimal health.\n\n"
        summary += "5. Avoid smoking and limit alcohol consumption.\n\n"
        
        // ===== DISCLAIMER =====
        summary += "IMPORTANT DISCLAIMER\n\n"
        summary += "This analysis is provided for informational purposes only and does not constitute medical advice, diagnosis, or treatment. Laboratory values should always be interpreted in the context of your complete medical history, symptoms, and physical examination by a qualified healthcare professional. If you have any concerns about your health or the findings in this report, please consult your physician or healthcare provider for proper clinical evaluation and guidance."
        
        return summary
    }
    
    /// Provides detailed clinical explanation for lab values in plain English
    private func getDetailedExplanation(testName: String, status: String, value: String) -> String {
        let name = testName.lowercased()
        let isHigh = status == "High" || status == "Critical"
        
        // Diabetes markers
        if name.contains("hba1c") || name.contains("glycated") {
            return isHigh ? 
                "Elevated HbA1c indicates that blood sugar levels have been higher than optimal over the past two to three months. This increases the risk of developing diabetes complications affecting the eyes, kidneys, nerves, and heart. Improved blood sugar control through medication, diet, and exercise may help lower this value." :
                "A low HbA1c value is generally favorable, though very low levels may sometimes indicate frequent episodes of low blood sugar (hypoglycemia), especially in individuals taking diabetes medications."
        }
        
        if name.contains("glucose") || name.contains("sugar") || name.contains("fbs") || name.contains("fasting") {
            return isHigh ?
                "Elevated blood glucose indicates that the body is not effectively regulating blood sugar levels. This may be seen in diabetes, prediabetes, or as a temporary effect of stress, illness, or certain medications. Persistent elevation requires medical evaluation." :
                "Low blood glucose (hypoglycemia) can cause symptoms such as shakiness, sweating, confusion, and dizziness. Severe cases require immediate treatment with fast-acting sugar and medical attention."
        }
        
        // Kidney markers
        if name.contains("creatinine") {
            return isHigh ?
                "Elevated creatinine is a significant finding that may indicate reduced kidney function. The kidneys normally filter creatinine from the blood, so elevated levels suggest the kidneys may not be working as efficiently as expected. This finding warrants further evaluation including medical history review and possibly additional kidney function tests." :
                "Low creatinine levels are typically not a cause for concern and may simply reflect reduced muscle mass or a vegetarian diet."
        }
        
        if name.contains("urea") || name.contains("bun") {
            return isHigh ?
                "Elevated blood urea nitrogen may indicate kidney dysfunction, dehydration, high protein intake, or gastrointestinal bleeding. This finding should be interpreted alongside other kidney function markers and clinical symptoms." :
                "Low blood urea nitrogen is usually not a clinical concern and may be seen with low protein intake or overhydration."
        }
        
        if name.contains("egfr") {
            return isHigh ?
                "A higher eGFR indicates better kidney filtration capacity, which is a positive finding." :
                "Reduced eGFR indicates decreased kidney filtration capacity. Values persistently below 60 mL/min for three months or more may indicate chronic kidney disease. This finding requires medical attention and possibly specialist referral."
        }
        
        // Liver markers
        if name.contains("sgpt") || name.contains("alt") {
            return isHigh ?
                "Elevated ALT (SGPT) suggests liver cell injury or inflammation. Common causes include fatty liver disease, viral hepatitis, alcohol consumption, certain medications, and metabolic conditions. Further evaluation may be needed to determine the underlying cause." :
                "Low ALT levels are generally not a clinical concern."
        }
        
        if name.contains("sgot") || name.contains("ast") {
            return isHigh ?
                "Elevated AST (SGOT) may indicate liver injury, but can also be elevated in heart or muscle conditions. It is typically evaluated alongside ALT for a more accurate assessment of liver health." :
                "Low AST levels are generally not a clinical concern."
        }
        
        if name.contains("bilirubin") {
            return isHigh ?
                "Elevated bilirubin can cause yellowing of the skin and eyes (jaundice). This may indicate liver disease, bile duct obstruction, or increased breakdown of red blood cells. Medical evaluation is recommended." :
                "Low bilirubin is typically not a clinical concern."
        }
        
        // Cardiovascular markers
        if name.contains("cholesterol") && name.contains("total") {
            return isHigh ?
                "Elevated total cholesterol increases the risk of developing atherosclerosis (hardening of the arteries) and cardiovascular disease. This can often be improved through dietary modifications, increased physical activity, and sometimes medication." :
                "Very low total cholesterol may affect hormone production and cell membrane integrity, though this is uncommon."
        }
        
        if name.contains("ldl") {
            return isHigh ?
                "Elevated LDL cholesterol, often called 'bad cholesterol,' contributes to the buildup of fatty deposits in the arteries. Reducing LDL through diet, exercise, and medication when needed can significantly lower cardiovascular risk." :
                "Lower LDL cholesterol levels are generally beneficial for cardiovascular health."
        }
        
        if name.contains("hdl") {
            return isHigh ?
                "Higher HDL cholesterol, often called 'good cholesterol,' is protective against heart disease as it helps remove other forms of cholesterol from the bloodstream." :
                "Low HDL cholesterol is associated with increased cardiovascular risk. Regular exercise, healthy fats, and avoiding smoking can help raise HDL levels."
        }
        
        if name.contains("triglyceride") {
            return isHigh ?
                "Elevated triglycerides increase the risk of heart disease and may be associated with metabolic syndrome. Dietary changes, weight management, reduced alcohol intake, and increased physical activity can help lower triglycerides." :
                "Low triglyceride levels are generally favorable."
        }
        
        // Blood markers
        if name.contains("hemoglobin") || name == "hb" {
            return isHigh ?
                "Elevated hemoglobin may indicate dehydration or certain blood disorders. It is important to ensure adequate hydration and follow up if levels remain elevated." :
                "Low hemoglobin indicates anemia, which can cause fatigue, weakness, and shortness of breath. The underlying cause should be investigated, as treatment depends on the specific type of anemia."
        }
        
        if name.contains("wbc") || name.contains("leukocyte") || name.contains("white blood") {
            return isHigh ?
                "Elevated white blood cell count often indicates the body is fighting an infection or inflammation. It can also be seen with stress, certain medications, or less commonly, blood disorders." :
                "Low white blood cell count may indicate bone marrow problems, certain viral infections, or immune system disorders. This finding may require additional evaluation."
        }
        
        // Default explanation
        return isHigh ?
            "This elevated value may indicate an abnormality that should be discussed with your healthcare provider for proper interpretation and management." :
            "This low value may indicate an abnormality that should be discussed with your healthcare provider for proper interpretation and management."
    }

    
    /// Provides clinical explanation for abnormal lab values
    private func getParameterExplanation(testName: String, status: String) -> String {
        let name = testName.lowercased()
        let isHigh = status == "High" || status == "Critical"
        
        // Diabetes markers
        if name.contains("hba1c") || name.contains("glycated") {
            return isHigh ? "Elevated HbA1c indicates poor blood sugar control over the past 2-3 months, increasing risk of diabetes complications." : "Low HbA1c is generally favorable but very low levels may indicate frequent hypoglycemia."
        }
        if name.contains("glucose") || name.contains("sugar") || name.contains("fbs") || name.contains("fasting") {
            return isHigh ? "Elevated blood glucose suggests inadequate blood sugar control and may require medication adjustment." : "Low blood glucose (hypoglycemia) can cause dizziness, confusion, and requires immediate attention."
        }
        
        // Kidney markers
        if name.contains("creatinine") {
            return isHigh ? "Elevated creatinine may indicate reduced kidney function. The kidneys filter creatinine from blood, so high levels suggest the kidneys may not be working efficiently." : "Low creatinine is usually not concerning but may indicate reduced muscle mass."
        }
        if name.contains("urea") || name.contains("bun") {
            return isHigh ? "Elevated blood urea nitrogen may indicate kidney dysfunction, dehydration, or high protein intake." : "Low BUN may indicate liver problems or malnutrition."
        }
        if name.contains("egfr") {
            return isHigh ? "Higher eGFR indicates better kidney function." : "Reduced eGFR indicates decreased kidney function. Values below 60 may suggest chronic kidney disease."
        }
        
        // Liver markers
        if name.contains("sgpt") || name.contains("alt") {
            return isHigh ? "Elevated ALT suggests liver cell damage. Common causes include fatty liver disease, medications, or hepatitis." : "Low ALT is generally not concerning."
        }
        if name.contains("sgot") || name.contains("ast") {
            return isHigh ? "Elevated AST may indicate liver or muscle damage. It should be evaluated alongside ALT for liver-specific assessment." : "Low AST is generally not concerning."
        }
        if name.contains("bilirubin") {
            return isHigh ? "Elevated bilirubin may cause jaundice (yellowing of skin/eyes) and can indicate liver dysfunction or bile duct problems." : "Low bilirubin is generally not concerning."
        }
        if name.contains("albumin") {
            return isHigh ? "High albumin is usually due to dehydration." : "Low albumin may indicate liver disease, kidney disease, or malnutrition."
        }
        
        // Cardiovascular markers
        if name.contains("cholesterol") && name.contains("total") {
            return isHigh ? "Elevated total cholesterol increases cardiovascular disease risk. Dietary changes and medications may help." : "Very low cholesterol may affect hormone production."
        }
        if name.contains("ldl") {
            return isHigh ? "Elevated LDL (bad cholesterol) increases risk of arterial plaque buildup and heart disease." : "Lower LDL is generally beneficial for heart health."
        }
        if name.contains("hdl") {
            return isHigh ? "Higher HDL (good cholesterol) is protective against heart disease." : "Low HDL increases cardiovascular risk. Exercise and healthy fats can help raise HDL."
        }
        if name.contains("triglyceride") {
            return isHigh ? "Elevated triglycerides increase heart disease risk and may indicate metabolic syndrome." : "Low triglycerides are generally favorable."
        }
        
        // Blood markers
        if name.contains("hemoglobin") || name == "hb" {
            return isHigh ? "Elevated hemoglobin may indicate dehydration or blood disorders." : "Low hemoglobin indicates anemia, which can cause fatigue and weakness."
        }
        if name.contains("wbc") || name.contains("leukocyte") || name.contains("white blood") {
            return isHigh ? "Elevated WBC may indicate infection, inflammation, or immune response." : "Low WBC may indicate bone marrow problems or immune deficiency."
        }
        if name.contains("platelet") {
            return isHigh ? "Elevated platelets may increase blood clotting risk." : "Low platelets may increase bleeding risk."
        }
        
        // Thyroid markers
        if name.contains("tsh") {
            return isHigh ? "Elevated TSH suggests underactive thyroid (hypothyroidism)." : "Low TSH may indicate overactive thyroid (hyperthyroidism)."
        }
        if name.contains("t3") || name.contains("t4") {
            return isHigh ? "Elevated thyroid hormones may indicate hyperthyroidism." : "Low thyroid hormones may indicate hypothyroidism."
        }
        
        // Electrolytes
        if name.contains("potassium") {
            return isHigh ? "Elevated potassium can affect heart rhythm and requires monitoring." : "Low potassium can cause muscle weakness and heart rhythm problems."
        }
        if name.contains("sodium") {
            return isHigh ? "Elevated sodium may indicate dehydration." : "Low sodium may cause confusion, fatigue, and muscle cramps."
        }
        
        // Vitamins
        if name.contains("vitamin d") || name.contains("25-hydroxy") {
            return isHigh ? "Very high vitamin D is rare but may cause calcium imbalance." : "Low vitamin D is common and can affect bone health, immunity, and mood."
        }
        if name.contains("b12") {
            return isHigh ? "High B12 is usually not concerning as excess is excreted." : "Low B12 can cause anemia, fatigue, and neurological symptoms."
        }
        
        // Generic response
        return isHigh ? "This value is above the normal reference range and should be discussed with your healthcare provider." : "This value is below the normal reference range and should be discussed with your healthcare provider."
    }
    
    func generateStaticReportSummary(report: MedicalReportModel, results: [LabResultModel], medications: [MedicationModel]) -> String {
        return "Summary for \(report.title)."
    }
    
    func getMedicationInfo(medicationName: String) async -> MedicationInfoResult {
        return MedicationInfoResult(description: "Info", sideEffects: [], recommendedDosage: "", recommendedFrequency: "")
    }
    
    func getParameterInfo(parameterName: String, age: Int, gender: String) async -> ParameterInfoResult {
        return ParameterInfoResult(description: "Info", normalRange: "")
    }
}

struct MedicalAnalysisResult: Codable {
    let reportType: String
    let reportDate: String?
    let labSource: String?
    let summary: String
    let labResults: [LabResultDTO]
    let medications: [MedicationDTO]
}

struct LabResultDTO: Codable {
    let testName: String
    let value: String
    let unit: String
    let status: String
    let category: String
    let organ: String?
    let normalRange: String
    let testDate: String?
}

struct MedicationDTO: Codable {
    let name: String
    let dosage: String
    let frequency: String
    let instructions: String?
}

struct MedicationInfoResult {
    let description: String
    let sideEffects: [String]
    let recommendedDosage: String
    let recommendedFrequency: String
}

struct ParameterInfoResult {
    let description: String
    let normalRange: String
}
