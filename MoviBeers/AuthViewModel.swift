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
        checkAuthentication()
    }
    
    private func checkAuthentication() {
        // Check if user is already signed in
        if authService.isUserAuthenticated(), let userId = authService.getCurrentUserId() {
            loadUser(userId: userId)
        } else {
            authState = .signedOut
        }
    }
    
    private func loadUser(userId: String) {
        Task {
            do {
                let user = try await authService.fetchUser(userId: userId)
                await MainActor.run {
                    self.user = user
                    self.authState = .signedIn
                    self.error = nil
                }
            } catch {
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
        do {
            try authService.signOut()
            self.user = nil
            self.authState = .signedOut
        } catch {
            self.error = "Failed to sign out"
        }
    }
    
    func updateProfile(username: String? = nil, bio: String? = nil, profileImageURL: String? = nil) {
        guard let userId = user?.id else { return }
        
        Task {
            do {
                try await authService.updateProfile(userId: userId, username: username, bio: bio, profileImageURL: profileImageURL)
                
                // Reload user data to reflect changes
                loadUser(userId: userId)
            } catch {
                await MainActor.run {
                    self.error = "Failed to update profile"
                }
            }
        }
    }
} 