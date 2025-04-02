//
//  TrackingView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI

struct TrackingView: View {
    @StateObject private var viewModel = TrackingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showingAddBeerSheet = false
    @State private var showingAddMovieSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Tracking Buttons
                VStack {
                    Text("What are you enjoying today?")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack(spacing: 20) {
                        // Beer Button
                        Button {
                            showingAddBeerSheet = true
                        } label: {
                            VStack {
                                Image(systemName: "mug.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.yellow)
                                Text("Track Beer")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow.opacity(0.1))
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            )
                        }
                        
                        // Movie Button
                        Button {
                            showingAddMovieSheet = true
                        } label: {
                            VStack {
                                Image(systemName: "film")
                                    .font(.system(size: 36))
                                    .foregroundColor(.red)
                                Text("Track Movie")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(.systemBackground))
                
                // MARK: - Recent Items List
                VStack(alignment: .leading) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    if viewModel.isLoading {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView("Loading your history...")
                            Spacer()
                        }
                        Spacer()
                    } else if viewModel.recentItems.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            Text("No recent activity")
                                .font(.headline)
                            Text("Start tracking beers and movies to see them here!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.recentItems) { item in
                                TrackItemRow(item: item)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await viewModel.loadRecentItems()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Track")
            .sheet(isPresented: $showingAddBeerSheet) {
                AddBeerView()
                    .onDisappear {
                        Task {
                            await viewModel.loadRecentItems()
                        }
                    }
            }
            .sheet(isPresented: $showingAddMovieSheet) {
                AddMovieView()
                    .onDisappear {
                        Task {
                            await viewModel.loadRecentItems()
                        }
                    }
            }
            .onAppear {
                Task {
                    await viewModel.loadRecentItems()
                }
            }
        }
    }
}

// MARK: - Track Item Row

struct TrackItemRow: View {
    let item: TrackItem
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.type == .beer ? Color.yellow.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.type == .beer ? "mug.fill" : "film")
                    .font(.system(size: 20))
                    .foregroundColor(item.type == .beer ? .yellow : .red)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Title and standardized indicator
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        
                        if let standardizedId = item.standardizedId, !standardizedId.isEmpty {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(item.type == .beer ? .yellow : .red)
                                .font(.system(size: 12))
                        }
                    }
                    
                    Spacer()
                    
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(item.type == .beer ? .yellow : .red)
                        Text("\(Int(item.rating))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Subtitle line
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Date & Time
                HStack(spacing: 12) {
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(item.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(item.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TrackingView()
            .environmentObject(AuthViewModel())
    }
} 