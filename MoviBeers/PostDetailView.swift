//
//  PostDetailView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import FirebaseFirestore

struct PostDetailView: View {
    let postId: String
    @StateObject private var viewModel = PostDetailViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    if let post = viewModel.post {
                        // Post content
                        PostRow(post: post)
                            .padding(.top)
                        
                        Divider()
                        
                        // Comment section
                        CommentSection(postId: postId, comments: viewModel.comments)
                    } else if !viewModel.isLoading {
                        // Post not found
                        VStack(spacing: 24) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            
                            Text("Post Not Found")
                                .font(.headline)
                            
                            Text("This post may have been deleted or is no longer available.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 80) // Extra space for keyboard
            }
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadPost(postId: postId)
                await viewModel.loadComments(postId: postId)
            }
        }
    }
}

struct CommentSection: View {
    let postId: String
    let comments: [PostInteraction]
    @State private var newCommentText = ""
    @State private var isLoading = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let databaseService = DatabaseService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
                .padding(.horizontal)
            
            if comments.isEmpty {
                Text("No comments yet. Be the first to share your thoughts!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                        .padding(.horizontal)
                    
                    if comment.id != comments.last?.id {
                        Divider()
                    }
                }
            }
            
            Spacer(minLength: 20)
            
            // Comment input
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
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            .padding(.horizontal)
        }
    }
    
    private func addComment() {
        guard !newCommentText.isEmpty, let userId = authViewModel.user?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Add comment
                _ = try await databaseService.addComment(postId: postId, userId: userId, text: newCommentText)
                
                // Clear input and refresh
                await MainActor.run {
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

class PostDetailViewModel: ObservableObject {
    @Published var post: Post?
    @Published var comments: [PostInteraction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let databaseService = DatabaseService()
    private let db = Firestore.firestore()
    
    func loadPost(postId: String) async {
        isLoading = true
        
        do {
            // Get post data
            let doc = try await db.collection("posts").document(postId).getDocument()
            
            if doc.exists, let data = doc.data() {
                var post = try Firestore.Decoder().decode(Post.self, from: data)
                post.id = doc.documentID
                
                await MainActor.run {
                    self.post = post
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.post = nil
                    self.isLoading = false
                    self.errorMessage = "Post not found"
                }
            }
        } catch {
            print("Error loading post: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Error loading post: \(error.localizedDescription)"
            }
        }
    }
    
    func loadComments(postId: String) async {
        do {
            let interactions = try await databaseService.getPostInteractions(postId: postId)
            
            await MainActor.run {
                self.comments = interactions.comments
            }
        } catch {
            print("Error loading comments: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(postId: "sample-post-id")
            .environmentObject(AuthViewModel())
    }
} 