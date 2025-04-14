//
//  ContentView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .signedIn:
                MainTabView()
                    .onAppear {
                        print("📱 Showing MainTabView - user is authenticated")
                    }
            case .signedOut:
                LoginView()
                    .onAppear {
                        print("📱 Showing LoginView - user is NOT authenticated")
                    }
            case .loading:
                LoadingView()
                    .onAppear {
                        print("📱 Showing LoadingView - auth state is loading")
                    }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationViewModel = NotificationTabViewModel()
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet")
                }
            
            TrackingView()
                .tabItem {
                    Label("Track", systemImage: "plus.circle")
                }
            
            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .badge(notificationViewModel.unreadCount > 0 ? notificationViewModel.unreadCount : 0)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
        }
        .onAppear {
            if let userId = authViewModel.user?.id {
                notificationViewModel.startFetchingUnreadCount(userId: userId)
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
            
            Text("Loading...")
                .font(.headline)
                .padding(.top, 20)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}

class NotificationTabViewModel: ObservableObject {
    @Published var unreadCount = 0
    private let databaseService = DatabaseService()
    private var timer: Timer?
    
    func startFetchingUnreadCount(userId: String) {
        // Immediately fetch the count
        fetchUnreadCount(userId: userId)
        
        // Set up a timer to periodically check for new notifications
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchUnreadCount(userId: userId)
        }
    }
    
    private func fetchUnreadCount(userId: String) {
        Task {
            do {
                let count = try await databaseService.getUnreadNotificationCount(userId: userId)
                await MainActor.run {
                    self.unreadCount = count
                }
            } catch {
                print("Error fetching unread notification count: \(error)")
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
