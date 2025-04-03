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
            FirebaseApp.configure()
            print("✅ Firebase initialized successfully")
            
            // Check if Auth is working
            if Auth.auth().currentUser != nil {
                print("👤 User is already signed in: \(Auth.auth().currentUser!.uid)")
            } else {
                print("👤 No user is currently signed in")
            }
            
            // Test database connection
            let db = Firestore.firestore()
            db.collection("test").document("connection").setData(["timestamp": FieldValue.serverTimestamp()]) { error in
                if let error = error {
                    print("🔴 Firebase Firestore connection test failed: \(error.localizedDescription)")
                } else {
                    print("✅ Firebase Firestore connection test successful!")
                }
            }
        } catch {
            print("🔴 Failed to initialize Firebase: \(error.localizedDescription)")
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
