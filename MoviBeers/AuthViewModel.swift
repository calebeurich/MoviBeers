//
//  AuthViewModel.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import Combine
import SwiftUI
import Firebase

enum AuthState {
    case signedIn
    case signedOut
    case loading
}

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var authState: AuthState = .loading
    @Published var error: String?
    
    private let authService = AuthService()
    private var cancellables = Set<AnyCancellable>()
    
    var isAuthenticated: Bool {
        return user != nil && authState == .signedIn
    }
    
    init() {
        print("🔄 Initializing AuthViewModel")
        checkAuthentication()
    }
    
    private func checkAuthentication() {
        // Check if user is already signed in
        print("🔍 Checking authentication status...")
        if authService.isUserAuthenticated(), let userId = authService.getCurrentUserId() {
            print("✅ User is authenticated with ID: \(userId)")
            loadUser(userId: userId)
        } else {
            print("ℹ️ No authenticated user found")
            authState = .signedOut
        }
    }
    
    private func loadUser(userId: String) {
        print("📥 Loading user data for ID: \(userId)")
        Task {
            do {
                let user = try await authService.fetchUser(userId: userId)
                await MainActor.run {
                    self.user = user
                    self.authState = .signedIn
                    self.error = nil
                    print("✅ User data loaded successfully: \(user.username)")
                }
            } catch {
                print("🔴 Failed to load user data: \(error.localizedDescription)")
                await MainActor.run {
                    self.authState = .signedOut
                    self.error = "Failed to load user data"
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        print("AuthViewModel: Starting sign in process")
        authState = .loading
        
        Task {
            do {
                print("AuthViewModel: Calling auth service sign in")
                let user = try await authService.signIn(email: email, password: password)
                await MainActor.run {
                    print("AuthViewModel: Sign in successful, updating UI state")
                    self.user = user
                    self.authState = .signedIn
                    self.error = nil
                }
            } catch {
                print("AuthViewModel: Sign in failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.authState = .signedOut
                    self.error = "Failed to sign in. Please check your email and password."
                }
            }
        }
    }
    
    func signUp(email: String, password: String, username: String) {
        print("AuthViewModel: Starting sign up process")
        authState = .loading
        
        Task {
            do {
                print("AuthViewModel: Calling auth service sign up")
                let user = try await authService.signUp(email: email, password: password, username: username)
                await MainActor.run {
                    print("AuthViewModel: Sign up successful, updating UI state")
                    self.user = user
                    self.authState = .signedIn
                    self.error = nil
                }
            } catch {
                print("AuthViewModel: Sign up failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.authState = .signedOut
                    self.error = "Failed to create account. Please try a different username or email."
                }
            }
        }
    }
    
    func signOut() {
        print("🔄 Signing out user")
        do {
            try authService.signOut()
            
            // Clear user data
            self.user = nil
            self.authState = .signedOut
            print("✅ User signed out successfully")
        } catch {
            print("🔴 Error signing out: \(error.localizedDescription)")
            self.error = "Failed to sign out"
        }
    }
    
    func updateProfile(username: String? = nil, bio: String? = nil, profileImageURL: String? = nil) {
        guard let userId = user?.id else { return }
        
        print("🔄 Updating profile for user ID: \(userId)")
        if let username = username {
            print("📝 New username: \(username)")
        }
        
        Task {
            do {
                // Verify if username is not already taken
                if let username = username, username != user?.username {
                    let usernameAvailable = try await authService.isUsernameAvailable(username: username, excludeUserId: userId)
                    if !usernameAvailable {
                        await MainActor.run {
                            self.error = "Username is already taken"
                        }
                        return
                    }
                }
                
                try await authService.updateProfile(userId: userId, username: username, bio: bio, profileImageURL: profileImageURL)
                
                // Reload user data to reflect changes
                loadUser(userId: userId)
                print("✅ Profile updated successfully")
            } catch {
                print("🔴 Failed to update profile: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = "Failed to update profile"
                }
            }
        }
    }
} 