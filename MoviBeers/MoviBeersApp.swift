//
//  MoviBeersApp.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import Firebase

@main
struct MoviBeersApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Verify GoogleService-Info.plist exists
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            print("✅ GoogleService-Info.plist found at: \(path)")
            if let dict = NSDictionary(contentsOfFile: path) {
                if let projectID = dict["PROJECT_ID"] as? String {
                    print("✅ Firebase Project ID: \(projectID)")
                } else {
                    print("⚠️ WARNING: GoogleService-Info.plist might be invalid - no PROJECT_ID found")
                }
            }
        } else {
            print("🔴 ERROR: GoogleService-Info.plist not found!")
        }
        
        // Configure Firebase
        print("⚙️ Configuring Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
