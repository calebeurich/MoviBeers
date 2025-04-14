//
//  Post.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore

enum PostType: String, Codable {
    case beer
    case movie
}

struct Post: Identifiable, Codable {
    var id: String?
    let userId: String
    let username: String
    let type: PostType
    let itemId: String // ID of the beer or movie
    let title: String // Beer name or movie title
    let subtitle: String? // Brand or director
    let location: String?
    let review: String?
    let rating: Int?
    let createdAt: Date
    let weekNumber: Int // Which beer/movie in the week
    let standardizedId: String? // ID from external API if selected from suggestions
    
    // For displaying in the feed
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case type
        case itemId
        case title
        case subtitle
        case location
        case review
        case rating
        case createdAt
        case weekNumber
        case standardizedId
    }
    
    // Helper method to check if this post is for a standardized item
    func isStandardized() -> Bool {
        return standardizedId != nil && !standardizedId!.isEmpty
    }
    
    static func fromFirestore(document: QueryDocumentSnapshot) -> Post? {
        do {
            var post = try Firestore.Decoder().decode(Post.self, from: document.data())
            post.id = document.documentID
            return post
        } catch {
            print("Error decoding post: \(error)")
            return nil
        }
    }
}

// For likes, comments, etc. (could be expanded)
struct PostInteraction: Identifiable, Codable {
    var id: String?
    let postId: String
    let userId: String
    let type: InteractionType
    let text: String?
    let createdAt: Date
    
    enum InteractionType: String, Codable {
        case like
        case comment
    }
} 