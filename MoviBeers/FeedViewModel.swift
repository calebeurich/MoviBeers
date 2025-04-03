//
//  FeedViewModel.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

class FeedViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Services
    
    private let databaseService = DatabaseService()
    
    // MARK: - Environment
    
    @ObservedObject var authViewModel: AuthViewModel
    
    // MARK: - Pagination
    
    private var lastDocument: DocumentSnapshot?
    private let limit = 10
    private var hasMorePosts = true
    
    // MARK: - Init
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        // Initialize with empty posts
    }
    
    // MARK: - Methods
    
    @MainActor
    func loadPosts() async {
        guard !isLoading else { return }
        
        // Check if user is authenticated and has a valid ID
        guard let userId = authViewModel.user?.id, !userId.isEmpty else {
            print("⚠️ Cannot load posts: No authenticated user or empty user ID")
            self.posts = []
            return
        }
        
        print("🔄 Starting to load posts for user: \(userId)")
        isLoading = true
        posts = []
        lastDocument = nil
        hasMorePosts = true
        
        do {
            print("📥 Fetching posts from database service...")
            let fetchedPosts = try await databaseService.getFeedPosts(userId: userId, limit: limit)
            print("✅ Fetched \(fetchedPosts.count) posts")
            
            self.posts = fetchedPosts
            // Since we don't have lastDocument in the current implementation, set hasMorePosts based on count
            self.hasMorePosts = fetchedPosts.count >= limit
            self.isLoading = false
        } catch {
            print("🔴 Error loading posts: \(error.localizedDescription)")
            self.errorMessage = "Failed to load posts: \(error.localizedDescription)"
            self.showError = true
            self.isLoading = false
        }
    }
    
    @MainActor
    func loadMorePosts() async {
        // Return if already loading or no more posts
        guard !isLoading && !isLoadingMore && hasMorePosts else { return }
        
        // Check if user is authenticated and has a valid ID
        guard let userId = authViewModel.user?.id, !userId.isEmpty else {
            print("⚠️ Cannot load more posts: No authenticated user or empty user ID")
            return
        }
        
        isLoadingMore = true
        
        do {
            // Since we don't have a lastDocument-based pagination in our current implementation,
            // we'll simply get more posts by increasing the limit
            let currentCount = posts.count
            let fetchedPosts = try await databaseService.getFeedPosts(
                userId: userId,
                limit: currentCount + limit
            )
            
            // Only add new posts that aren't already in our list
            let newPosts = Array(fetchedPosts.dropFirst(currentCount))
            
            if !newPosts.isEmpty {
                self.posts.append(contentsOf: newPosts)
                self.hasMorePosts = newPosts.count >= limit
            } else {
                self.hasMorePosts = false
            }
            
            self.isLoadingMore = false
        } catch {
            self.errorMessage = "Failed to load more posts: \(error.localizedDescription)"
            self.showError = true
            self.isLoadingMore = false
        }
    }
} 