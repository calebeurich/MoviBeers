//
//  MoviBeersApp.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

@main
struct MoviBeersApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Configure Firebase only once during app initialization
        setupFirebase()
    }
    
    private func setupFirebase() {
        print("🔥 Initializing Firebase...")
        do {
            // Configure Firebase
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
                print("✅ Firebase initialized successfully")
            } else {
                print("ℹ️ Firebase already initialized")
            }
            
            // Check if Auth is working
            if Auth.auth().currentUser != nil {
                print("👤 User is already signed in: \(Auth.auth().currentUser!.uid)")
            } else {
                print("👤 No user is currently signed in")
            }
        } catch {
            print("🔴 Failed to initialize Firebase: \(error.localizedDescription)")
            // Don't throw here, just log the error
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onAppear {
                    print("🔍 ContentView appeared, auth state: \(authViewModel.authState), isAuthenticated: \(authViewModel.isAuthenticated)")
                }
        }
    }
}
