//
//  MoviBeersApp.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import Firebase
import FirebaseAppCheck
import FirebaseAuth

@main
struct MoviBeersApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Configure Firebase only once during app initialization
        configureFirebase()
    }
    
    private func configureFirebase() {
        // STEP 1: Set up App Check with the simplest possible configuration
        print("🔐 Setting up Firebase App Check...")
        
        #if DEBUG
        // For DEBUG builds, use the Debug Provider
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("✅ Debug provider configured for development")
        
        // Note: For debug provider to work in simulator, you need to:
        // 1. Register the debug token in Firebase Console
        // 2. Have the token in your .env file
        // 3. Register your app in Firebase Console App Check section
        if let token = readDebugTokenFromEnv() {
            print("ℹ️ Debug token found: \(String(token.prefix(4)))...")
            // We're not setting it programmatically - just log it's available
            // Firebase will find it through the standard mechanisms
        }
        #else
        // For RELEASE builds, use Device Check
        let providerFactory = DeviceCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("✅ Device Check provider configured for production")
        #endif
        
        // STEP 2: Initialize Firebase AFTER setting the provider factory
        print("🔥 Initializing Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
    }
    
    // Just read the token from env file - we don't try to set it programmatically
    private func readDebugTokenFromEnv() -> String? {
        guard let path = Bundle.main.path(forResource: ".env", ofType: nil),
              let content = try? String(contentsOfFile: path) else {
            return nil
        }
        
        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("APP_CHECK_DEBUG_TOKEN=") {
                let value = line.replacingOccurrences(of: "APP_CHECK_DEBUG_TOKEN=", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "\"", with: "")
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
