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
    @Published var size: String = ""
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
    @Published var standardizedName: String = ""
    @Published var shouldStandardizeName: Bool = true
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
    
    func standardizeBeerName() {
        if shouldStandardizeName && !name.isEmpty {
            standardizedName = apiService.standardizeBeerName(name)
        } else {
            standardizedName = name
        }
    }
    
    func searchPopularBeers() {
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()
        
        // If the search text is empty, clear suggestions
        if name.isEmpty {
            self.popularSuggestions = []
            return
        }
        
        // Create a new timer for debouncing
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Don't search if text is too short
            guard self.name.count >= 2 else {
                self.popularSuggestions = []
                return
            }
            
            // Create a task to perform the search
            Task { @MainActor in
                // Get popular beer suggestions based on user entries
                let suggestions = await self.apiService.getPopularBeerSuggestions(query: self.name)
                
                // Update the suggestions
                self.popularSuggestions = suggestions
            }
        }
    }
    
    func selectSuggestion(_ suggestion: String) {
        self.name = suggestion
        standardizeBeerName()
    }
    
    func validateForm() -> Bool {
        guard !name.isEmpty else {
            self.errorMessage = "Beer name cannot be empty"
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
                // Get final name (use standardized if enabled)
                let finalName = shouldStandardizeName ? standardizedName : name
                
                // Call the DatabaseService.addBeer method directly
                try await databaseService.addBeer(
                    userId: userId,
                    name: finalName,
                    size: size.isEmpty ? nil : size,
                    location: nil,
                    review: notes.isEmpty ? nil : notes,
                    rating: Int(rating),
                    type: type.isEmpty ? nil : type,
                    abv: nil,
                    standardizedId: nil // No external standardization now
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
        standardizedName = ""
        size = ""
        type = ""
        rating = 3.0
        notes = ""
        shouldStandardizeName = true
        popularSuggestions = []
        selectedImage = nil
    }
} 