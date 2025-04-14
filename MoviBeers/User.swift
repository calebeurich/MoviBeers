//
//  User.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String?
    var username: String
    var email: String
    var bio: String?
    var joinDate: Date
    var currentWeekBeers: Int
    var currentWeekMovies: Int
    var totalBeers: Int
    var totalMovies: Int
    var currentStreak: Int
    var recordStreak: Int
    var following: [String]
    var followers: [String]
    var weeklyHistory: [WeeklyStats]
    
    // UI-only properties, not stored in Firestore
    var isFollowing: Bool? = false
    
    // Computed properties
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: joinDate)
    }
    
    var displayName: String {
        return username
    }
}

struct WeeklyStats: Codable, Identifiable {
    var id: String
    var weekStartDate: Date
    var weekEndDate: Date
    var beersConsumed: Int
    var moviesWatched: Int
    var completedWeek: Bool
    
    // Computed property for week identifier
    var weekIdentifier: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: weekStartDate)
    }
    
    // Formatted date ranges for display
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: weekEndDate))"
    }
} 