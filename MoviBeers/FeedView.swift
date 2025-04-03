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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack(spacing: 10) {
                // Profile image
                if let profileImageUrl = post.userProfileImage, !profileImageUrl.isEmpty {
                    AsyncImage(url: URL(string: profileImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        case .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
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
                    Text("\(post.rating)/5")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Like button (placeholder)
                Button {
                    // Like action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 14))
                        Text("Like")
                            .font(.callout)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Comment button (placeholder)
                Button {
                    // Comment action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 14))
                        Text("Comment")
                            .font(.callout)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
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
            
            // Image
            if let imageUrl = post.imageURL, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                Image(systemName: post.type == PostType.beer ? "mug.fill" : "film")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Notes
            if let notes = post.review, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeedView()
            .environmentObject(AuthViewModel())
    }
} 