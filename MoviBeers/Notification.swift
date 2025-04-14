//
//  Notification.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case like
    case comment
    case follow
}

struct Notification: Identifiable, Codable {
    var id: String?
    let recipientId: String // The user who receives the notification
    let senderId: String // The user who triggered the notification
    let senderUsername: String
    let type: NotificationType
    let postId: String? // Optional - only for like/comment notifications
    let postTitle: String? // Optional - post title for context
    let commentText: String? // Optional - only for comment notifications
    let createdAt: Date
    var isRead: Bool
    
    // For display in the UI
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // Message based on notification type
    var message: String {
        switch type {
        case .like:
            return "\(senderUsername) liked your post"
        case .comment:
            if let text = commentText, !text.isEmpty {
                if text.count > 30 {
                    return "\(senderUsername) commented: \(text.prefix(30))..."
                }
                return "\(senderUsername) commented: \(text)"
            }
            return "\(senderUsername) commented on your post"
        case .follow:
            return "\(senderUsername) started following you"
        }
    }
} 