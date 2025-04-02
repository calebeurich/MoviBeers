//
//  ProfileView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile View")
                    .font(.title)
                    .padding()
                
                Button(action: {
                    authViewModel.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
} 