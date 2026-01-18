import SwiftUI
import SwiftData
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - App Delegate for Firebase Initialization

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        print("🚀 [AppDelegate] Firebase configured successfully")
        
        return true
    }
}

// MARK: - Main App

@main
struct DiaboApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Create a shared model container with migration support
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MedicalReportModel.self,
            UserProfileModel.self,
            LabResultModel.self,
            MedicationModel.self,
            ParameterTrendModel.self,
            TimelineEntryModel.self,
            AIChatMessage.self,
            HealthMetricModel.self,
            LabGraphDataModel.self  // NEW: For time-series graph data
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration: Delete old store if incompatible
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to delete old data store and recreate...")
            
            // Get the default store URL
            let url = modelConfiguration.url
            
            // Delete the old store files
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            
            // Try creating container again with fresh store
            do {
                let freshContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ ModelContainer recreated successfully with fresh schema")
                return freshContainer
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    
    var body: some Scene {
        WindowGroup {
            RootContentView()
                .preferredColorScheme(.light) // Force light mode for consistent appearance
        }
        .modelContainer(DiaboApp.sharedModelContainer)
    }
}
