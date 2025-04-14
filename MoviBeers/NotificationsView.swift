//
//  NotificationsView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import FirebaseFirestore

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Content
                notificationsContent
                
                // Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.notifications.isEmpty {
                        Button("Mark All Read") {
                            viewModel.markAllAsRead()
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .refreshable {
                if let userId = authViewModel.user?.id {
                    await viewModel.loadNotifications(userId: userId)
                }
            }
            .onAppear {
                if let userId = authViewModel.user?.id {
                    Task {
                        await viewModel.loadNotifications(userId: userId)
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.shouldNavigateToPost) {
                if let postId = viewModel.selectedPost {
                    PostDetailView(postId: postId)
                        .onDisappear {
                            viewModel.resetNavigation()
                        }
                } else {
                    // Fallback to feed if somehow no postId is available
                    Text("Post not found")
                        .onAppear {
                            viewModel.resetNavigation()
                        }
                }
            }
            .navigationDestination(isPresented: $viewModel.shouldNavigateToProfile) {
                if let userId = viewModel.selectedUser {
                    ProfileView(userId: userId)
                        .onDisappear {
                            viewModel.resetNavigation()
                        }
                } else {
                    // Fallback to empty view if somehow no userId is available
                    Text("User not found")
                        .onAppear {
                            viewModel.resetNavigation()
                        }
                }
            }
        }
    }
    
    private var notificationsContent: some View {
        Group {
            if viewModel.notifications.isEmpty && !viewModel.isLoading {
                VStack(spacing: 24) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Notifications")
                        .font(.headline)
                    
                    Text("When someone likes or comments on your posts, or follows you, you'll see it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.markAsRead(notificationId: notification.id)
                                viewModel.handleNotificationTap(notification)
                            }
                            .listRowBackground(notification.isRead ? Color(.systemBackground) : Color.blue.opacity(0.1))
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct NotificationRow: View {
    let notification: Notification
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(iconColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Message
                Text(notification.message)
                    .font(.subheadline)
                    .lineLimit(2)
                
                // Time
                Text(notification.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Icon based on notification type
    private var iconName: String {
        switch notification.type {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.right.fill"
        case .follow:
            return "person.fill.badge.plus"
        }
    }
    
    // Color based on notification type
    private var iconColor: Color {
        switch notification.type {
        case .like:
            return .red
        case .comment:
            return .blue
        case .follow:
            return .green
        }
    }
}

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var selectedPost: String? = nil
    @Published var selectedUser: String? = nil
    @Published var shouldNavigateToPost = false
    @Published var shouldNavigateToProfile = false
    
    private let databaseService = DatabaseService()
    
    func loadNotifications(userId: String) async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedNotifications = try await databaseService.getNotifications(userId: userId)
            
            await MainActor.run {
                notifications = fetchedNotifications
                isLoading = false
            }
        } catch {
            print("Error loading notifications: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func markAsRead(notificationId: String?) {
        guard let id = notificationId else { return }
        
        Task {
            do {
                try await databaseService.markNotificationAsRead(notificationId: id)
                
                // Update the local state
                await MainActor.run {
                    if let index = notifications.firstIndex(where: { $0.id == id }) {
                        notifications[index].isRead = true
                    }
                }
            } catch {
                print("Error marking notification as read: \(error)")
            }
        }
    }
    
    func markAllAsRead() {
        guard !notifications.isEmpty else { return }
        
        // recipientId is not optional in the Notification struct, so no need for optional binding
        let userId = notifications.first!.recipientId
        
        isLoading = true
        
        Task {
            do {
                try await databaseService.markAllNotificationsAsRead(userId: userId)
                
                // Update the local state
                await MainActor.run {
                    for i in 0..<notifications.count {
                        notifications[i].isRead = true
                    }
                    isLoading = false
                }
            } catch {
                print("Error marking all notifications as read: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    func handleNotificationTap(_ notification: Notification) {
        print("Tapped notification: \(notification.type) - \(notification.message)")
        
        // Navigate based on notification type
        switch notification.type {
        case .like, .comment:
            if let postId = notification.postId {
                selectedPost = postId
                shouldNavigateToPost = true
            }
        case .follow:
            // senderId is not optional in the Notification struct
            selectedUser = notification.senderId
            shouldNavigateToProfile = true
        }
    }
    
    func resetNavigation() {
        selectedPost = nil
        selectedUser = nil
        shouldNavigateToPost = false
        shouldNavigateToProfile = false
    }
}

#Preview {
    NotificationsView()
        .environmentObject(AuthViewModel())
} 