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
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
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
