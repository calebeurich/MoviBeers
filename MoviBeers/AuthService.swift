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
import UIKit

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
            
            // Standard flow for all environments
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
            
            // Save user to Firestore
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
                
                // Handle case where Auth user exists but Firestore document doesn't
                // This can happen if account was just created or data wasn't properly synced
                if auth.currentUser != nil {
                    print("⚠️ Auth user exists but no Firestore document - creating default user document")
                    
                    // Get email from Auth
                    let email = auth.currentUser?.email ?? "unknown@email.com"
                    
                    // Create a basic user object
                    let newUser = User(
                        id: userId,
                        username: "User\(userId.prefix(6))",  // Create a default username
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
                    
                    // Create the user document
                    let userData = try Firestore.Encoder().encode(newUser)
                    try await db.collection("users").document(userId).setData(userData)
                    print("✅ Created new user document for existing auth user")
                    
                    return newUser
                } else {
                    throw AuthError.userNotFound
                }
            }
        } catch {
            print("🔴 Error fetching user: \(error.localizedDescription)")
            throw AuthError.userNotFound
        }
    }
    
    func updateProfile(userId: String, username: String? = nil, bio: String? = nil, profileImageURL: String? = nil) async throws {
        do {
            // Create batch to update in a single transaction
            let batch = db.batch()
            let userRef = db.collection("users").document(userId)
            
            // Build user update data
            var updateData: [String: Any] = [:]
            
            if let username = username {
                updateData["username"] = username
                
                // Update all posts by this user to have the new username
                let postsSnapshot = try await db.collection("posts")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                for document in postsSnapshot.documents {
                    let postRef = db.collection("posts").document(document.documentID)
                    batch.updateData([
                        "username": username
                    ], forDocument: postRef)
                }
                
                print("Will update username in \(postsSnapshot.documents.count) posts")
            }
            
            if let bio = bio {
                updateData["bio"] = bio
            }
            
            if let profileImageURL = profileImageURL {
                updateData["profileImageURL"] = profileImageURL
            }
            
            if !updateData.isEmpty {
                // Add user document update to batch
                batch.updateData(updateData, forDocument: userRef)
                
                // Commit all changes
                try await batch.commit()
                print("✅ Profile update batch committed successfully")
            }
        } catch {
            print("🔴 Profile update failed: \(error.localizedDescription)")
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
    
    // MARK: - Username Validation
    
    func isUsernameAvailable(username: String, excludeUserId: String? = nil) async throws -> Bool {
        do {
            let query = db.collection("users").whereField("username", isEqualTo: username)
            let snapshot = try await query.getDocuments()
            
            // If no documents found, username is available
            if snapshot.documents.isEmpty {
                return true
            }
            
            // If we're excluding a user ID (for example, the current user during an update)
            if let excludeUserId = excludeUserId {
                // Username is available only if all documents with this username belong to the excluded user
                return snapshot.documents.allSatisfy { $0.documentID == excludeUserId }
            }
            
            // Username is taken
            return false
        } catch {
            print("Error checking username availability: \(error.localizedDescription)")
            throw error
        }
    }
}

// Helper extension for simulator detection
#if !RELEASE
extension UIDevice {
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
#endif 