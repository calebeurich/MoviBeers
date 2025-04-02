//
//  Movie.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore

struct Movie: Identifiable, Codable {
    var id: String?
    let userId: String
    let title: String
    let director: String?
    let year: Int?
    let location: String? // Theatre name, streaming service, etc.
    let review: String?
    let rating: Int? // 1-5 stars
    let watchedAt: Date
    let weekNumber: Int // Which movie in the week (1-3)
    let weekStartDate: Date // For identifying which week this belongs to
    
    // Optional fields
    let posterURL: String?
    let genre: String?
    let runtime: Int? // in minutes
    
    // Standardization field - links to external database ID if the user selected from suggestions
    let standardizedId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case director
        case year
        case location
        case review
        case rating
        case watchedAt
        case weekNumber
        case weekStartDate
        case posterURL
        case genre
        case runtime
        case standardizedId
    }
    
    // Helper method to check if this movie is a standardized entry
    func isStandardized() -> Bool {
        return standardizedId != nil && !standardizedId!.isEmpty
    }
} 