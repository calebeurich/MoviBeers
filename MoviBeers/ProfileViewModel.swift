import Foundation
import SwiftUI
import FirebaseFirestore

enum UserListType {
    case followers
    case following
}

class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: User?
    @Published var followers: [User] = []
    @Published var following: [User] = []
    @Published var searchResults: [User] = []
    @Published var isLoading: Bool = false
    @Published var searchQuery: String = ""
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Services
    
    private let db = Firestore.firestore()
    
    // MARK: - Methods
    
    func loadUserProfile(userId: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if userDoc.exists, let userData = userDoc.data() {
                var user = try Firestore.Decoder().decode(User.self, from: userData)
                user.id = userDoc.documentID
                
                await MainActor.run {
                    self.user = user
                    self.isLoading = false
                }
                
                // Load followers and following
                await loadFollowers(userId: userId)
                await loadFollowing(userId: userId)
            } else {
                await MainActor.run {
                    self.errorMessage = "User profile not found"
                    self.showError = true
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func loadFollowers(userId: String) async {
        do {
            guard let user = self.user else {
                await MainActor.run {
                    self.followers = []
                }
                return
            }
            
            let followerIds = user.followers
            
            // If there are no followers, return empty array
            if followerIds.isEmpty {
                await MainActor.run {
                    self.followers = []
                }
                return
            }
            
            // Query users where their ID is in the followers array
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: followerIds)
                .getDocuments()
            
            let fetchedFollowers = snapshot.documents.compactMap { doc -> User? in
                do {
                    var user = try Firestore.Decoder().decode(User.self, from: doc.data())
                    user.id = doc.documentID
                    return user
                } catch {
                    print("Error decoding follower: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.followers = fetchedFollowers
            }
        } catch {
            print("Error loading followers: \(error)")
            await MainActor.run {
                self.followers = []
            }
        }
    }
    
    func loadFollowing(userId: String) async {
        do {
            guard let user = self.user else {
                await MainActor.run {
                    self.following = []
                }
                return
            }
            
            let followingIds = user.following
            
            // If there are no following, return empty array
            if followingIds.isEmpty {
                await MainActor.run {
                    self.following = []
                }
                return
            }
            
            // Query users where their ID is in the following array
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: followingIds)
                .getDocuments()
            
            let fetchedFollowing = snapshot.documents.compactMap { doc -> User? in
                do {
                    var user = try Firestore.Decoder().decode(User.self, from: doc.data())
                    user.id = doc.documentID
                    return user
                } catch {
                    print("Error decoding following: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.following = fetchedFollowing
            }
        } catch {
            print("Error loading following: \(error)")
            await MainActor.run {
                self.following = []
            }
        }
    }
    
    func searchUsers() async {
        guard !searchQuery.isEmpty else {
            await MainActor.run {
                self.searchResults = []
            }
            return
        }
        
        do {
            // Search for users where username starts with the search query
            let snapshot = try await db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: searchQuery)
                .whereField("username", isLessThan: searchQuery + "z")
                .limit(to: 10)
                .getDocuments()
            
            let results = snapshot.documents.compactMap { doc -> User? in
                do {
                    var user = try Firestore.Decoder().decode(User.self, from: doc.data())
                    user.id = doc.documentID
                    
                    // Check if the current user is following this user
                    if let currentUserId = self.user?.id,
                       let userIdToCheck = user.id,
                       self.user?.following.contains(userIdToCheck) == true {
                        user.isFollowing = true
                    } else {
                        user.isFollowing = false
                    }
                    
                    return user
                } catch {
                    print("Error decoding search result: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.searchResults = results
            }
        } catch {
            print("Error searching users: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to search users"
                self.showError = true
                self.searchResults = []
            }
        }
    }
    
    func followUser(userId: String, currentUserId: String) async {
        do {
            let batch = db.batch()
            
            // Add userId to current user's following list
            let currentUserRef = db.collection("users").document(currentUserId)
            batch.updateData([
                "following": FieldValue.arrayUnion([userId])
            ], forDocument: currentUserRef)
            
            // Add currentUserId to userId's followers list
            let userRef = db.collection("users").document(userId)
            batch.updateData([
                "followers": FieldValue.arrayUnion([currentUserId])
            ], forDocument: userRef)
            
            try await batch.commit()
            
            // Update local state
            await MainActor.run {
                // Update user in search results
                if let index = self.searchResults.firstIndex(where: { $0.id == userId }) {
                    self.searchResults[index].isFollowing = true
                }
                
                // Update current user's following list
                if var user = self.user {
                    user.following.append(userId)
                    self.user = user
                }
            }
            
            // Reload following list
            await loadFollowing(userId: currentUserId)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to follow user"
                self.showError = true
            }
        }
    }
    
    func unfollowUser(userId: String, currentUserId: String) async {
        do {
            let batch = db.batch()
            
            // Remove userId from current user's following list
            let currentUserRef = db.collection("users").document(currentUserId)
            batch.updateData([
                "following": FieldValue.arrayRemove([userId])
            ], forDocument: currentUserRef)
            
            // Remove currentUserId from userId's followers list
            let userRef = db.collection("users").document(userId)
            batch.updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ], forDocument: userRef)
            
            try await batch.commit()
            
            // Update local state
            await MainActor.run {
                // Update user in search results
                if let index = self.searchResults.firstIndex(where: { $0.id == userId }) {
                    self.searchResults[index].isFollowing = false
                }
                
                // Update current user's following list
                if var user = self.user, let index = user.following.firstIndex(of: userId) {
                    user.following.remove(at: index)
                    self.user = user
                }
                
                // Update following list
                if let index = self.following.firstIndex(where: { $0.id == userId }) {
                    self.following.remove(at: index)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unfollow user"
                self.showError = true
            }
        }
    }
    
    // MARK: - Profile Update
    
    func updateUsername(userId: String, newUsername: String) async -> Bool {
        do {
            // First, check if the username is already taken
            let usernameQuery = try await db.collection("users")
                .whereField("username", isEqualTo: newUsername)
                .getDocuments()
            
            // If we found any docs with this username (except the current user's doc), username is taken
            if !usernameQuery.documents.isEmpty {
                // Check if the found document belongs to the current user
                let isCurrentUser = usernameQuery.documents.contains { $0.documentID == userId }
                
                if !isCurrentUser {
                    await MainActor.run {
                        self.errorMessage = "Username is already taken"
                        self.showError = true
                    }
                    return false
                }
            }
            
            // Start a batch operation
            let batch = db.batch()
            
            // 1. Update the username in the user document
            let userRef = db.collection("users").document(userId)
            batch.updateData([
                "username": newUsername
            ], forDocument: userRef)
            
            // 2. Update the username in all posts by this user
            let postsSnapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for document in postsSnapshot.documents {
                let postRef = db.collection("posts").document(document.documentID)
                batch.updateData([
                    "username": newUsername
                ], forDocument: postRef)
            }
            
            // Commit all the updates in one batch
            try await batch.commit()
            
            print("✅ Username updated successfully to: \(newUsername) in user profile and \(postsSnapshot.documents.count) posts")
            
            // Update local state
            await MainActor.run {
                if var user = self.user {
                    user.username = newUsername
                    self.user = user
                }
            }
            
            return true
        } catch {
            print("🔴 Error updating username: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to update username: \(error.localizedDescription)"
                self.showError = true
            }
            return false
        }
    }
} 