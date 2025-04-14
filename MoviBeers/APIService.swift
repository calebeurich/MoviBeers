//
//  APIService.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
    case serverError(Int)
    case unknown
}

class APIService {
    // MARK: - HTTP Client
    
    private let session = URLSession.shared
    private let jsonDecoder = JSONDecoder()
    private let databaseService = DatabaseService()
    
    // MARK: - Standardization Methods
    
    func standardizeMovieTitle(_ title: String) -> String {
        // Simple standardization function that capitalizes words and ensures proper spacing
        let words = title.split(separator: " ").map { word -> String in
            // Skip certain words from capitalization if they're not at the beginning
            let lowercaseWords = ["a", "an", "the", "and", "but", "or", "for", "nor", "on", "at", "to", "from", "by", "with", "in", "of"]
            let wordString = word.lowercased()
            
            // Capitalize the first character if it's not a lowercase word or it's the first word
            if !lowercaseWords.contains(wordString) || wordString == title.lowercased().prefix(word.count) {
                if let firstChar = wordString.first {
                    return String(firstChar).uppercased() + wordString.dropFirst()
                }
            }
            
            return wordString
        }
        
        return words.joined(separator: " ")
    }
    
    func standardizeBeerName(_ name: String) -> String {
        // Similar to movie titles, but with specific handling for beer names
        // Beer names often have specific capitalization patterns
        
        let words = name.split(separator: " ").map { word -> String in
            let wordString = word.lowercased()
            
            // Words that are typically lowercase in beer names
            let lowercaseWords = ["and", "or", "with", "on", "the", "a", "an", "in", "by", "for"]
            
            // Special abbreviations in beer names should be all caps
            let upperCaseWords = ["ipa", "dipa", "neipa", "xpa", "aipa", "ipl"]
            
            if upperCaseWords.contains(wordString) {
                return wordString.uppercased()
            } else if !lowercaseWords.contains(wordString) || wordString == name.lowercased().prefix(word.count) {
                if let firstChar = wordString.first {
                    return String(firstChar).uppercased() + wordString.dropFirst()
                }
            }
            
            return wordString
        }
        
        return words.joined(separator: " ")
    }
    
    func standardizeBrand(_ brand: String) -> String {
        // Brand names typically have all major words capitalized
        let words = brand.split(separator: " ").map { word -> String in
            let wordString = word.lowercased()
            
            // Very few words would be lowercase in a brand name
            let lowercaseWords = ["and", "of", "the"]
            
            if !lowercaseWords.contains(wordString) || wordString == brand.lowercased().prefix(word.count) {
                if let firstChar = wordString.first {
                    return String(firstChar).uppercased() + wordString.dropFirst()
                }
            }
            
            return wordString
        }
        
        return words.joined(separator: " ")
    }
    
    // MARK: - User-based Suggestion Methods
    
    // Get movie suggestions based on popularity from database
    func getPopularMovieSuggestions(query: String) async -> [String] {
        // Call the database service to get popular movie suggestions
        return await databaseService.getPopularMovieSuggestions(query: query)
    }
    
    // Get beer suggestions based on popularity from database
    func getPopularBeerSuggestions(query: String) async -> [String] {
        // Call the database service to get popular beer suggestions
        return await databaseService.getPopularBeerSuggestions(query: query)
    }
} 