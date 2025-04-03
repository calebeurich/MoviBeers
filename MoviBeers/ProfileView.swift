//
//  ProfileView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI

enum ProfileTab {
    case profile
    case followers
    case following
    case search
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab: ProfileTab = .profile
    @State private var searchText = ""
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var isSubmittingUsername = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // User info section
                if let user = authViewModel.user {
                    userHeaderView(user: user)
                }
                
                // Tab selection
                tabSelectionView()
                
                // Content based on selected tab
                tabContentView()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        authViewModel.signOut()
                    } label: {
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                loadUserData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $isEditingUsername) {
                editUsernameView()
            }
        }
    }
    
    // MARK: - Component Views
    
    private func userHeaderView(user: User) -> some View {
        VStack(spacing: 16) {
            // Profile image and stats
            HStack(spacing: 24) {
                // Profile image
                if let profileImageURL = user.profileImageURL, !profileImageURL.isEmpty {
                    AsyncImage(url: URL(string: profileImageURL)) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        case .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
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
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                // Stats
                HStack(spacing: 24) {
                    statsView(title: "Beers", value: "\(user.totalBeers)")
                    statsView(title: "Movies", value: "\(user.totalMovies)")
                    statsView(title: "Streak", value: "\(user.currentStreak)")
                }
            }
            .padding(.top)
            
            // Username and bio
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.username)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button {
                        newUsername = user.username
                        isEditingUsername = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                    }
                }
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Text("Joined \(user.formattedJoinDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                    .padding(.top)
        }
    }
    
    private func statsView(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func tabSelectionView() -> some View {
        HStack(spacing: 0) {
            tabButton(title: "Profile", tab: .profile)
            tabButton(title: "Followers", tab: .followers)
            tabButton(title: "Following", tab: .following)
            tabButton(title: "Search", tab: .search)
        }
        .padding(.top, 8)
    }
    
    private func tabButton(title: String, tab: ProfileTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                
                Rectangle()
                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func tabContentView() -> some View {
        ZStack {
            switch selectedTab {
            case .profile:
                profileTabContent()
            case .followers:
                followersTabContent()
            case .following:
                followingTabContent()
            case .search:
                searchTabContent()
            }
        }
    }
    
    // MARK: - Tab Contents
    
    private func profileTabContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stats")
                    .font(.headline)
                    .padding(.horizontal)
                
                if let user = authViewModel.user {
                    HStack(spacing: 12) {
                        // Current week stats
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This Week")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 16) {
                                Label("\(user.currentWeekBeers)", systemImage: "mug.fill")
                                    .foregroundColor(.yellow)
                                
                                Label("\(user.currentWeekMovies)", systemImage: "film")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // All-time stats
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All Time")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 16) {
                                Label("\(user.totalBeers)", systemImage: "mug.fill")
                                    .foregroundColor(.yellow)
                                
                                Label("\(user.totalMovies)", systemImage: "film")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Best streak
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Record Streak")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Label("\(user.recordStreak) days", systemImage: "flame.fill")
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private func followersTabContent() -> some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading followers...")
            } else if viewModel.followers.isEmpty {
                VStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("No followers yet")
                        .font(.headline)
                    
                    Text("When other users follow you, they'll appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.followers) { user in
                            UserRow(user: user, currentUserId: authViewModel.user?.id ?? "", allowFollow: true, onFollow: { userId in
                                Task {
                                    await viewModel.followUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            }, onUnfollow: { userId in
                                Task {
                                    await viewModel.unfollowUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            })
                            
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
    
    private func followingTabContent() -> some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading following...")
            } else if viewModel.following.isEmpty {
                VStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Not following anyone yet")
                        .font(.headline)
                    
                    Text("Search for users to follow in the Search tab.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.following) { user in
                            UserRow(user: user, currentUserId: authViewModel.user?.id ?? "", allowFollow: true, onFollow: { userId in
                                Task {
                                    await viewModel.followUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            }, onUnfollow: { userId in
                                Task {
                                    await viewModel.unfollowUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            })
                            
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
    
    private func searchTabContent() -> some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users", text: $viewModel.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        Task {
                            await viewModel.searchUsers()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top)
            
            // Search results
            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                VStack {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("No users found")
                        .font(.headline)
                    
                    Text("Try a different search term or check the spelling.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { user in
                            UserRow(user: user, currentUserId: authViewModel.user?.id ?? "", allowFollow: true, onFollow: { userId in
                                Task {
                                    await viewModel.followUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            }, onUnfollow: { userId in
                                Task {
                                    await viewModel.unfollowUser(userId: userId, currentUserId: authViewModel.user?.id ?? "")
                                }
                            })
                            
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() {
        if let userId = authViewModel.user?.id {
            Task {
                await viewModel.loadUserProfile(userId: userId)
            }
        }
    }
    
    private func editUsernameView() -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Change Username")
                    .font(.headline)
                    .padding(.top)
                
                TextField("New Username", text: $newUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("Choose a unique username that will be visible to other users.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    updateUsername()
                } label: {
                    if isSubmittingUsername {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        Text("Save Username")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .disabled(isSubmittingUsername || newUsername.isEmpty || (newUsername == authViewModel.user?.username))
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isEditingUsername = false
                    }
                }
            }
        }
    }
    
    private func updateUsername() {
        guard !newUsername.isEmpty,
              let userId = authViewModel.user?.id else {
            return
        }
        
        isSubmittingUsername = true
        
        Task {
            let success = await viewModel.updateUsername(userId: userId, newUsername: newUsername)
            
            await MainActor.run {
                isSubmittingUsername = false
                if success {
                    // Also update username in AuthViewModel
                    if var user = authViewModel.user {
                        user.username = newUsername
                        authViewModel.user = user
                    }
                    isEditingUsername = false
                }
            }
        }
    }
}

// MARK: - User Row Component

struct UserRow: View {
    let user: User
    let currentUserId: String
    let allowFollow: Bool
    let onFollow: (String) -> Void
    let onUnfollow: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let profileImageURL = user.profileImageURL, !profileImageURL.isEmpty {
                AsyncImage(url: URL(string: profileImageURL)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 44, height: 44)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Follow/Unfollow button (if it's not the current user)
            if allowFollow && user.id != currentUserId {
                Button {
                    if user.isFollowing == true {
                        onUnfollow(user.id ?? "")
                    } else {
                        onFollow(user.id ?? "")
                    }
                } label: {
                    Text(user.isFollowing == true ? "Unfollow" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(user.isFollowing == true ? .primary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(user.isFollowing == true ? Color(.systemGray5) : Color.accentColor)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
} 