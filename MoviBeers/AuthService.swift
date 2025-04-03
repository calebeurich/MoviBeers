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
            
            #if targetEnvironment(simulator)
            // Special handling for simulator environment to handle AppCheck issues
            do {
                return try await fetchUser(userId: userId)
            } catch let error as NSError {
                // Check if this is the specific AppCheck error in simulator
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
                   UIDevice.current.isSimulator {
                    print("⚠️ Caught expected AppCheck error in simulator during sign-in - creating temporary user")
                    
                    // For simulator development only - create a temporary user object
                    // This allows sign-in to work even if Firestore access fails due to AppCheck
                    print("✅ Created temporary user for simulator testing")
                    return User(
                        id: userId,
                        username: "TestUser",
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
                } else {
                    // Some other Firestore error - rethrow it
                    print("🔴 Error fetching user data after sign-in: \(error.localizedDescription)")
                    throw error
                }
            }
            #else
            // Regular flow for physical devices
            return try await fetchUser(userId: userId)
            #endif
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
            
            #if targetEnvironment(simulator)
            // Special handling for simulator environment to handle AppCheck issues
            var usernameExists = false
            do {
                print("Checking if username is available (simulator)...")
                let usernameQuery = try await db.collection("users")
                    .whereField("username", isEqualTo: username)
                    .getDocuments()
                
                usernameExists = !usernameQuery.documents.isEmpty
            } catch let error as NSError {
                // Check if this is the specific AppCheck error in simulator
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
                   UIDevice.current.isSimulator {
                    print("⚠️ Caught expected AppCheck error in simulator - continuing with username check workaround")
                    // We'll proceed with the assumption username is available in the simulator
                    // This is only for development - not production
                    usernameExists = false
                } else {
                    // Some other Firestore error - rethrow it
                    throw error
                }
            }
            
            if usernameExists {
                print("🔴 Username already exists")
                throw AuthError.signUpError // Username already in use
            }
            #else
            // Regular flow for physical devices
            print("Checking if username is available...")
            let usernameQuery = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            
            if !usernameQuery.documents.isEmpty {
                print("🔴 Username already exists")
                throw AuthError.signUpError // Username already in use
            }
            #endif
            
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
            
            do {
                print("Writing to Firestore collection 'users', document: \(userId)")
                try await db.collection("users").document(userId).setData(userData)
                print("✅ User document created in Firestore")
            } catch let error as NSError {
                // Check if this is the specific AppCheck error in simulator
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
                   UIDevice.current.isSimulator {
                    print("⚠️ Caught expected AppCheck error in simulator when creating user document - continuing with user creation")
                    // We'll proceed with the user object even though we couldn't save to Firestore
                    // This is only for simulator development
                } else {
                    // For any other error, or on a real device, propagate the error
                    print("🔴 Failed to create user document: \(error.localizedDescription)")
                    throw error
                }
            }
            
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
            
            // Detect AppCheck errors specifically for better error messages
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                if UIDevice.current.isSimulator {
                    print("⚠️ AppCheck verification failed in simulator - this is expected during development")
                } else {
                    print("🔴 AppCheck verification failed on real device - check your Firebase AppCheck configuration")
                }
            }
            
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