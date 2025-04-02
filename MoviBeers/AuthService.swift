//
//  AuthService.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum AuthError: Error {
    case signInError
    case signUpError
    case signOutError
    case userNotFound
    case profileUpdateFailed
}

class AuthService {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // MARK: - User Authentication
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            print("Attempting to sign in with email: \(email)")
            let authResult = try await auth.signIn(withEmail: email, password: password)
            print("Auth sign in successful for user: \(authResult.user.uid)")
            
            // Fetch user data from Firestore
            let userId = authResult.user.uid
            return try await fetchUser(userId: userId)
        } catch let error as NSError {
            print("🔴 Sign-in error: \(error.localizedDescription)")
            print("🔴 Error domain: \(error.domain), code: \(error.code)")
            print("🔴 Error details: \(error.userInfo)")
            throw AuthError.signInError
        }
    }
    
    func signUp(email: String, password: String, username: String) async throws -> User {
        do {
            print("Starting sign up process for email: \(email), username: \(username)")
            
            // Check if username is available
            print("Checking if username is available...")
            let usernameQuery = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            
            if !usernameQuery.documents.isEmpty {
                print("🔴 Username already exists")
                throw AuthError.signUpError // Username already in use
            }
            
            print("Username is available, proceeding with auth user creation")
            
            // Create Auth user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let userId = authResult.user.uid
            print("✅ Firebase Auth user created with ID: \(userId)")
            
            // Create user document in Firestore
            print("Creating Firestore user document...")
            var newUser = User(
                id: userId,
                username: username,
                email: email,
                profileImageURL: nil,
                bio: nil,
                joinDate: Date(),
                currentWeekBeers: 0,
                currentWeekMovies: 0,
                totalBeers: 0,
                totalMovies: 0,
                currentStreak: 0,
                recordStreak: 0,
                following: [],
                followers: [],
                weeklyHistory: []
            )
            
            // Save to Firestore - convert to dictionary manually
            print("Encoding user data...")
            let userData = try Firestore.Encoder().encode(newUser)
            print("Writing to Firestore collection 'users', document: \(userId)")
            try await db.collection("users").document(userId).setData(userData)
            print("✅ User document created in Firestore")
            
            return newUser
        } catch let error as NSError {
            print("🔴 Sign-up error: \(error.localizedDescription)")
            print("🔴 Error domain: \(error.domain), code: \(error.code)")
            print("🔴 Error details: \(error.userInfo)")
            throw AuthError.signUpError
        }
    }
    
    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            throw AuthError.signOutError
        }
    }
    
    // MARK: - User Data
    
    func fetchUser(userId: String) async throws -> User {
        do {
            print("Fetching user with ID: \(userId)")
            let documentSnapshot = try await db.collection("users").document(userId).getDocument()
            
            if documentSnapshot.exists {
                print("Document exists, attempting to decode...")
                var user = try Firestore.Decoder().decode(User.self, from: documentSnapshot.data() ?? [:])
                // Make sure to set the ID field manually
                user.id = documentSnapshot.documentID
                print("✅ User data fetched and decoded successfully")
                return user
            } else {
                print("🔴 User document not found in Firestore")
                throw AuthError.userNotFound
            }
        } catch let error as NSError {
            print("🔴 Error fetching user: \(error.localizedDescription)")
            print("🔴 Error domain: \(error.domain), code: \(error.code)")
            print("🔴 Error details: \(error.userInfo)")
            throw AuthError.userNotFound
        }
    }
    
    func updateProfile(userId: String, username: String?, bio: String?, profileImageURL: String?) async throws {
        do {
            var updateData: [String: Any] = [:]
            
            if let username = username {
                updateData["username"] = username
            }
            
            if let bio = bio {
                updateData["bio"] = bio
            }
            
            if let profileImageURL = profileImageURL {
                updateData["profileImageURL"] = profileImageURL
            }
            
            if !updateData.isEmpty {
                try await db.collection("users").document(userId).updateData(updateData)
            }
        } catch {
            throw AuthError.profileUpdateFailed
        }
    }
    
    // MARK: - Current User
    
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }
    
    func isUserAuthenticated() -> Bool {
        return auth.currentUser != nil
    }
} 