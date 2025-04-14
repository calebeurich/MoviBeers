//
//  TrackingViewModel.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class TrackingViewModel: ObservableObject {
    @Published var recentItems: [TrackItem] = []
    @Published var isLoading = false
    
    private let databaseService = DatabaseService()
    
    init() {
        // Items will be loaded when view appears
    }
    
    func loadRecentItems() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.recentItems = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Fetch both beer and movie tracking items
        do {
            // Load beers
            let beers = try await databaseService.getBeersForUser(userId: userId)
            let beerItems = beers.map { beer in
                TrackItem(
                    id: beer.id ?? UUID().uuidString,
                    type: .beer,
                    name: beer.name,
                    subtitle: beer.size ?? "Unknown size",
                    rating: Double(beer.rating ?? 0),
                    timestamp: beer.consumedAt,
                    standardizedId: beer.standardizedId
                )
            }
            
            // Load movies
            let movies = try await databaseService.getMoviesForUser(userId: userId)
            let movieItems = movies.map { movie in
                TrackItem(
                    id: movie.id ?? UUID().uuidString,
                    type: .movie,
                    name: movie.title,
                    subtitle: movie.director ?? "Unknown director",
                    rating: Double(movie.rating ?? 0),
                    timestamp: movie.watchedAt,
                    standardizedId: movie.standardizedId
                )
            }
            
            // Combine and sort by timestamp (newest first)
            let combinedItems = (beerItems + movieItems).sorted { $0.timestamp > $1.timestamp }
            
            // Take only the most recent items (e.g., 30)
            self.recentItems = Array(combinedItems.prefix(30))
        } catch {
            print("Error loading tracking items: \(error.localizedDescription)")
            self.recentItems = []
        }
    }
} 