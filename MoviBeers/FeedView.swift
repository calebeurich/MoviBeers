//
//  FeedView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import FirebaseFirestore

struct FeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: FeedViewModel
    
    init() {
        // This is a temporary authViewModel for preview purposes only
        // The real one will be passed in .onAppear
        self._viewModel = StateObject(wrappedValue: FeedViewModel(authViewModel: AuthViewModel()))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Content
                feedContent
                
                // Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                }
            }
            .navigationTitle("Feed")
            .refreshable {
                if authViewModel.isAuthenticated {
                    await viewModel.loadPosts()
                }
            }
            .onAppear {
                // Update the viewModel to use the correct authViewModel
                viewModel.authViewModel = authViewModel
                
                Task {
                    // Only load posts if the user is authenticated
                    if authViewModel.isAuthenticated {
                        await viewModel.loadPosts()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        Group {
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                VStack(spacing: 24) {
                    Image(systemName: "bubbles.and.sparkles")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No posts yet!")
                        .font(.headline)
                    
                    Text("When you and your friends track beers and movies, they'll show up here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.posts) { post in
                            PostRow(post: post)
                                .onAppear {
                                    // Load more posts when reaching the end
                                    if post.id == viewModel.posts.last?.id {
                                        Task {
                                            await viewModel.loadMorePosts()
                                        }
                                    }
                                }
                        }
                        
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

// MARK: - Post Row

struct PostRow: View {
    let post: Post
    @State private var isLiked = false
    @State private var showComments = false
    @State private var commentText = ""
    @State private var comments: [PostInteraction] = []
    @State private var likes: Int = 0
    @State private var isLoading = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let databaseService = DatabaseService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack(spacing: 10) {
                // User icon replacement for profile image
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
                
                // User info and post time
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    // Date and time
                    HStack(spacing: 6) {
                        Text(formatDate(date: post.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(date: post.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Post type icon
                Image(systemName: post.type == PostType.beer ? "mug.fill" : "film")
                    .foregroundColor(post.type == PostType.beer ? .yellow : .red)
            }
            
            // MARK: - Post Content
            PostContent(post: post)
            
            // MARK: - Post Stats
            HStack(spacing: 20) {
                // Rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(post.type == PostType.beer ? .yellow : .red)
                        .font(.system(size: 14))
                    Text("\(post.rating ?? 0)/5")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Like button (now functional)
                Button {
                    toggleLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likes)")
                            .font(.callout)
                            .foregroundColor(isLiked ? .red : .secondary)
                    }
                }
                .disabled(isLoading || post.id == nil)
                
                // Comment button (now shows comments sheet)
                Button {
                    showComments = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 14))
                        Text("\(comments.count)")
                            .font(.callout)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
            
            // Display comments if there are any
            if !comments.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                ForEach(comments.prefix(2)) { comment in
                    CommentRow(comment: comment)
                }
                
                if comments.count > 2 {
                    Button("View all \(comments.count) comments") {
                        showComments = true
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showComments) {
            // Only pass the post ID if it's valid
            if let postId = post.id {
                CommentsView(postId: postId, comments: $comments)
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            loadInteractions()
        }
    }
    
    // MARK: - Interaction Methods
    
    private func loadInteractions() {
        guard let postId = post.id else { return }
        
        isLoading = true
        Task {
            do {
                let interactions = try await databaseService.getPostInteractions(postId: postId)
                await MainActor.run {
                    likes = interactions.likes
                    comments = interactions.comments
                    
                    // Check if current user has liked this post
                    if let userId = authViewModel.user?.id {
                        isLiked = comments.contains { $0.userId == userId && $0.type == .like }
                    }
                    
                    isLoading = false
                }
            } catch {
                print("Error loading interactions: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleLike() {
        guard let postId = post.id, let userId = authViewModel.user?.id else { return }
        
        isLoading = true
        isLiked.toggle() // Optimistic UI update
        
        // Update like count immediately for better UX
        likes += isLiked ? 1 : -1
        
        Task {
            do {
                if isLiked {
                    try await databaseService.likePost(postId: postId, userId: userId)
                } else {
                    try await databaseService.unlikePost(postId: postId, userId: userId)
                }
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                // Revert on error
                await MainActor.run {
                    isLiked.toggle()
                    likes += isLiked ? 1 : -1
                    isLoading = false
                }
            }
        }
    }
    
    // Format date for display
    private func formatDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }
    
    // Format time for display
    private func formatTime(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: date)
    }
}

// MARK: - Post Content

struct PostContent: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            HStack(spacing: 4) {
                Text(post.title)
                    .font(.headline)
                
                // Standardization badge
                if let standardizedId = post.standardizedId, !standardizedId.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(post.type == PostType.beer ? .yellow : .red)
                        .font(.system(size: 12))
                }
            }
            
            // Subtitle
            if let subtitle = post.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Post type icon (replacement for image)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 100)
                .overlay(
                    Image(systemName: post.type == PostType.beer ? "mug.fill" : "film")
                        .font(.largeTitle)
                        .foregroundColor(post.type == PostType.beer ? .yellow : .red)
                )
                .padding(.vertical, 8)
            
            // Notes
            if let notes = post.review, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Comments View
struct CommentsView: View {
    let postId: String
    @Binding var comments: [PostInteraction]
    @State private var newCommentText = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let databaseService = DatabaseService()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Comments List
                List {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .listStyle(PlainListStyle())
                
                // New Comment Input
                HStack {
                    TextField("Add a comment...", text: $newCommentText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button {
                        addComment()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(newCommentText.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addComment() {
        guard !newCommentText.isEmpty, let userId = authViewModel.user?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Add to database
                let newComment = try await databaseService.addComment(
                    postId: postId, 
                    userId: userId, 
                    text: newCommentText
                )
                
                // Update UI
                await MainActor.run {
                    comments.append(newComment)
                    newCommentText = ""
                    isLoading = false
                }
            } catch {
                print("Error adding comment: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: PostInteraction
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // User icon
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Comment text
                Text(comment.text ?? "")
                    .font(.body)
                
                // Timestamp
                Text(formatDate(date: comment.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeedView()
            .environmentObject(AuthViewModel())
    }
} 