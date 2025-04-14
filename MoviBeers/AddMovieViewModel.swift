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
    @Published var standardizedTitle: String = ""
    @Published var shouldStandardizeTitle: Bool = true
    @Published var popularSuggestions: [String] = []
    
    // MARK: - Services
    
    private let databaseService: DatabaseService
    private let apiService: APIService
    
    // MARK: - Debouncing Search
    
    private var searchDebounceTimer: Timer?
    
    // MARK: - Init
    
    init(databaseService: DatabaseService = DatabaseService(),
         apiService: APIService = APIService()) {
        self.databaseService = databaseService
        self.apiService = apiService
    }
    
    // MARK: - Methods
    
    func standardizeTitle() {
        if shouldStandardizeTitle && !title.isEmpty {
            standardizedTitle = apiService.standardizeMovieTitle(title)
        } else {
            standardizedTitle = title
        }
    }
    
    func searchPopularMovies() {
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()
        
        // If the search text is empty, clear suggestions
        if title.isEmpty {
            self.popularSuggestions = []
            return
        }
        
        // Create a new timer for debouncing
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Don't search if text is too short
            guard self.title.count >= 2 else {
                self.popularSuggestions = []
                return
            }
            
            // Create a task to perform the search
            Task { @MainActor in
                // Get popular movie suggestions based on user entries
                let suggestions = await self.apiService.getPopularMovieSuggestions(query: self.title)
                
                // Update the suggestions
                self.popularSuggestions = suggestions
            }
        }
    }
    
    func selectSuggestion(_ suggestion: String) {
        self.title = suggestion
        standardizeTitle()
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
                // If title standardization is enabled, use the standardized title
                let finalTitle = shouldStandardizeTitle ? standardizedTitle : title
                
                // Create movie object
                let yearInt = year.isEmpty ? nil : Int(year)
                
                // Call the DatabaseService.addMovie method
                try await databaseService.addMovie(
                    userId: userId, 
                    title: finalTitle, 
                    director: director.isEmpty ? nil : director, 
                    year: yearInt, 
                    location: nil, 
                    review: notes.isEmpty ? nil : notes, 
                    rating: Int(rating), 
                    genre: nil, 
                    runtime: nil, 
                    standardizedId: nil // No external standardization now
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
        standardizedTitle = ""
        director = ""
        year = ""
        rating = 3.0
        notes = ""
        shouldStandardizeTitle = true
        popularSuggestions = []
        selectedImage = nil
    }
} 