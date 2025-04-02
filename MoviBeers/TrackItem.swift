//
//  TrackItem.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation

enum TrackItemType: String, Codable {
    case beer
    case movie
}

struct TrackItem: Identifiable {
    let id: String
    let type: TrackItemType
    let name: String
    let subtitle: String
    let rating: Double
    let date: String
    let time: String
    let standardizedId: String?
    let timestamp: Date
    
    init(id: String = UUID().uuidString,
         type: TrackItemType,
         name: String,
         subtitle: String,
         rating: Double,
         timestamp: Date = Date(),
         standardizedId: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.subtitle = subtitle
        self.rating = rating
        self.standardizedId = standardizedId
        self.timestamp = timestamp
        
        // Format date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        self.date = dateFormatter.string(from: timestamp)
        
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        self.time = dateFormatter.string(from: timestamp)
    }
}

// For parsing from Firestore
extension TrackItem {
    init?(from dictionary: [String: Any], id: String) {
        guard let typeRaw = dictionary["type"] as? String,
              let type = TrackItemType(rawValue: typeRaw),
              let name = dictionary["name"] as? String,
              let subtitle = dictionary["subtitle"] as? String,
              let rating = dictionary["rating"] as? Double,
              let timestamp = dictionary["timestamp"] as? Date else {
            return nil
        }
        
        self.id = id
        self.type = type
        self.name = name
        self.subtitle = subtitle
        self.rating = rating
        self.timestamp = timestamp
        self.standardizedId = dictionary["standardizedId"] as? String
        
        // Format date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        self.date = dateFormatter.string(from: timestamp)
        
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        self.time = dateFormatter.string(from: timestamp)
    }
} 