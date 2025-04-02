//
//  AddMovieViewModel.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

class AddMovieViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form Data
    @Published var title: String = ""
    @Published var director: String = ""
    @Published var year: String = ""
    @Published var rating: Double = 3.0
    @Published var notes: String = ""
    @Published var selectedImage: UIImage?
    
    // UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var successMessage: String?
    @Published var showSuccess: Bool = false
    
    // Standardization
    @Published var movieSuggestions: [MovieSuggestion] = []
    @Published var isSearching: Bool = false
    @Published var selectedSuggestion: MovieSuggestion?
    
    // MARK: - Services
    
    private let databaseService: DatabaseService
    private let storageService: StorageService
    private let apiService: APIService
    
    // MARK: - Debouncing Search
    
    private var searchDebounceTimer: Timer?
    
    // MARK: - Init
    
    init(databaseService: DatabaseService = DatabaseService(),
         storageService: StorageService = StorageService(),
         apiService: APIService = APIService()) {
        self.databaseService = databaseService
        self.storageService = storageService
        self.apiService = apiService
    }
    
    // MARK: - Methods
    
    func searchMovies() {
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()
        
        // If the search text is empty, clear suggestions
        if title.isEmpty {
            self.movieSuggestions = []
            return
        }
        
        // Create a new timer for debouncing
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Don't search if text is too short
            guard self.title.count >= 2 else {
                self.movieSuggestions = []
                return
            }
            
            // Mark as searching
            self.isSearching = true
            
            // Create a task to perform the search
            Task { @MainActor in
                do {
                    // Search for movies
                    let suggestions = try await self.apiService.searchMovies(query: self.title)
                    
                    // Update the suggestions
                    self.movieSuggestions = suggestions
                    self.isSearching = false
                    
                } catch {
                    // Handle errors
                    print("Error searching for movies: \(error.localizedDescription)")
                    self.movieSuggestions = []
                    self.isSearching = false
                }
            }
        }
    }
    
    func selectSuggestion(_ suggestion: MovieSuggestion) {
        self.selectedSuggestion = suggestion
        self.title = suggestion.title
        if let year = suggestion.year {
            self.year = String(year)
        }
    }
    
    func clearSelection() {
        self.selectedSuggestion = nil
    }
    
    func validateForm() -> Bool {
        guard !title.isEmpty else {
            self.errorMessage = "Movie title cannot be empty"
            self.showError = true
            return false
        }
        
        if !year.isEmpty {
            guard let yearInt = Int(year), yearInt > 1800 && yearInt <= Calendar.current.component(.year, from: Date()) else {
                self.errorMessage = "Please enter a valid year"
                self.showError = true
                return false
            }
        }
        
        return true
    }
    
    func addMovie(userId: String) {
        // Validate form
        guard validateForm() else { return }
        
        // Set loading state
        self.isLoading = true
        
        // Create a task to add the movie
        Task { @MainActor in
            do {
                // Check if we have a standardized ID
                let standardizedId = selectedSuggestion?.id
                
                // Upload image if available
                var imageUrl: String?
                if let image = selectedImage {
                    imageUrl = try await storageService.uploadPostImage(userId: userId, type: "movie", image: image)
                } else if let suggestion = selectedSuggestion, let suggestionImageUrl = suggestion.imageURL {
                    // Use the suggestion image URL if available
                    imageUrl = suggestionImageUrl
                }
                
                // Create movie object
                let yearInt = year.isEmpty ? nil : Int(year)
                
                // Call the DatabaseService.addMovie method instead of directly creating a Movie
                try await databaseService.addMovie(
                    userId: userId, 
                    title: title, 
                    director: director.isEmpty ? nil : director, 
                    year: yearInt, 
                    location: nil, 
                    review: notes.isEmpty ? nil : notes, 
                    rating: Int(rating), 
                    posterURL: imageUrl, 
                    genre: nil, 
                    runtime: nil, 
                    standardizedId: standardizedId
                )
                
                // Reset form
                resetForm()
                
                // Show success message
                self.successMessage = "Movie added successfully!"
                self.showSuccess = true
                self.isLoading = false
                
            } catch {
                // Handle errors
                self.errorMessage = "Failed to add movie: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func resetForm() {
        title = ""
        director = ""
        year = ""
        rating = 3.0
        notes = ""
        selectedImage = nil
        selectedSuggestion = nil
        movieSuggestions = []
    }
} 