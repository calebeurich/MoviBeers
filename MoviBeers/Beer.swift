//
//  Beer.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore

struct Beer: Identifiable, Codable {
    var id: String?
    let userId: String
    let name: String
    let size: String? // Size like "12oz", "16oz", "Pint", etc.
    let location: String?
    let review: String?
    let rating: Int? // 1-5 stars
    let consumedAt: Date
    let weekNumber: Int // Which beer in the week (1-20)
    let weekStartDate: Date // For identifying which week this belongs to
    
    // Optional fields
    let type: String? // IPA, Stout, etc.
    let abv: Double? // Alcohol by volume
    
    // Standardization field - links to external database ID if the user selected from suggestions
    let standardizedId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case size
        case location
        case review
        case rating
        case consumedAt
        case weekNumber
        case weekStartDate
        case type
        case abv
        case standardizedId
    }
    
    // Helper method to check if this beer is a standardized entry
    func isStandardized() -> Bool {
        return standardizedId != nil && !standardizedId!.isEmpty
    }
} 