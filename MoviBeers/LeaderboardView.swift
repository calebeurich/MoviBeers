//
//  LeaderboardView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Leaderboard View")
                    .font(.title)
                    .padding()
                
                Text("Weekly rankings will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Leaderboard")
        }
    }
} 