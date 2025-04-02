//
//  AddBeerViewModel.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

class AddBeerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form Data
    @Published var name: String = ""
    @Published var brand: String = ""
    @Published var type: String = ""
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
    @Published var beerSuggestions: [BeerSuggestion] = []
    @Published var isSearching: Bool = false
    @Published var selectedSuggestion: BeerSuggestion?
    
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
    
    func searchBeers() {
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()
        
        // If the search text is empty, clear suggestions
        if name.isEmpty {
            self.beerSuggestions = []
            return
        }
        
        // Create a new timer for debouncing
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Don't search if text is too short
            guard self.name.count >= 2 else {
                self.beerSuggestions = []
                return
            }
            
            // Mark as searching
            self.isSearching = true
            
            // Create a task to perform the search
            Task { @MainActor in
                do {
                    // Search for beers
                    let suggestions = try await self.apiService.searchBeers(query: self.name)
                    
                    // Update the suggestions
                    self.beerSuggestions = suggestions
                    self.isSearching = false
                    
                } catch {
                    // Handle errors
                    print("Error searching for beers: \(error.localizedDescription)")
                    self.beerSuggestions = []
                    self.isSearching = false
                }
            }
        }
    }
    
    func selectSuggestion(_ suggestion: BeerSuggestion) {
        self.selectedSuggestion = suggestion
        self.name = suggestion.name
        self.brand = suggestion.brand
        if let type = suggestion.type {
            self.type = type
        }
    }
    
    func clearSelection() {
        self.selectedSuggestion = nil
    }
    
    func validateForm() -> Bool {
        guard !name.isEmpty else {
            self.errorMessage = "Beer name cannot be empty"
            self.showError = true
            return false
        }
        
        guard !brand.isEmpty else {
            self.errorMessage = "Brand name cannot be empty"
            self.showError = true
            return false
        }
        
        return true
    }
    
    func addBeer(userId: String) {
        // Validate form
        guard validateForm() else { return }
        
        // Set loading state
        self.isLoading = true
        
        // Create a task to add the beer
        Task { @MainActor in
            do {
                // Check if we have a standardized ID
                let standardizedId = selectedSuggestion?.id
                
                // Upload image if available
                var imageUrl: String?
                if let image = selectedImage {
                    imageUrl = try await storageService.uploadPostImage(userId: userId, type: "beer", image: image)
                }
                
                // Call the DatabaseService.addBeer method directly
                try await databaseService.addBeer(
                    userId: userId,
                    name: name,
                    brand: brand,
                    location: nil,
                    review: notes.isEmpty ? nil : notes,
                    rating: Int(rating),
                    imageURL: imageUrl,
                    type: type.isEmpty ? nil : type,
                    abv: nil,
                    standardizedId: standardizedId
                )
                
                // Reset form
                resetForm()
                
                // Show success message
                self.successMessage = "Beer added successfully!"
                self.showSuccess = true
                self.isLoading = false
                
            } catch {
                // Handle errors
                self.errorMessage = "Failed to add beer: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func resetForm() {
        name = ""
        brand = ""
        type = ""
        rating = 3.0
        notes = ""
        selectedImage = nil
        selectedSuggestion = nil
        beerSuggestions = []
    }
} 