//
//  DatabaseService.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseFirestore
import UIKit

enum DatabaseError: Error {
    case fetchError
    case saveError
    case updateError
    case deleteError
    case weekCalculationError
}

class DatabaseService {
    private let db = Firestore.firestore()
    
    // MARK: - Beer Tracking
    
    func addBeer(userId: String, name: String, size: String?, location: String?, review: String?, rating: Int?, type: String?, abv: Double?, standardizedId: String? = nil) async throws -> Beer {
        do {
            print("Adding beer: \(name) for user: \(userId)")
            // Get current week data
            let (weekStartDate, weekNumber) = try await getCurrentWeekData(userId: userId, type: .beer)
            
            // Create beer object
            let beer = Beer(
                userId: userId,
                name: name,
                size: size,
                location: location,
                review: review,
                rating: rating,
                consumedAt: Date(),
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                type: type,
                abv: abv,
                standardizedId: standardizedId
            )
            
            // Save to Firestore - using manual encoding
            let beerData = try Firestore.Encoder().encode(beer)
            
            // Simple save to Firestore without simulator-specific error handling
            let docRef = try await db.collection("beers").addDocument(data: beerData)
            print("✅ Beer saved with ID: \(docRef.documentID)")
            let beerId = docRef.documentID
            
            // Update user stats
            try await updateUserStats(userId: userId, type: .beer)
            
            // Create post
            try await createPost(
                userId: userId,
                type: .beer,
                itemId: beerId,
                title: name,
                subtitle: size ?? "",
                location: location,
                review: review,
                rating: rating,
                weekNumber: weekNumber,
                standardizedId: standardizedId
            )
            
            // Get beer with document ID
            var beerWithId = beer
            beerWithId.id = beerId
            return beerWithId
        } catch {
            print("🔴 Error adding beer: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func getBeersForUser(userId: String, limit: Int? = nil) async throws -> [Beer] {
        do {
            var query = db.collection("beers")
                .whereField("userId", isEqualTo: userId)
                .order(by: "consumedAt", descending: true)
            
            if let limit = limit {
                query = query.limit(to: limit)
            }
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { document in
                do {
                    var beer = try Firestore.Decoder().decode(Beer.self, from: document.data())
                    beer.id = document.documentID
                    return beer
                } catch {
                    print("Error decoding beer: \(error)")
                    return nil
                }
            }
        } catch {
            throw DatabaseError.fetchError
        }
    }
    
    // MARK: - Movie Tracking
    
    func addMovie(userId: String, title: String, director: String?, year: Int?, location: String?, review: String?, rating: Int?, genre: String?, runtime: Int?, standardizedId: String? = nil) async throws -> Movie {
        do {
            print("Adding movie: \(title) for user: \(userId)")
            // Get current week data
            let (weekStartDate, weekNumber) = try await getCurrentWeekData(userId: userId, type: .movie)
            
            // Create movie object
            let movie = Movie(
                userId: userId,
                title: title,
                director: director,
                year: year,
                location: location,
                review: review,
                rating: rating,
                watchedAt: Date(),
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                genre: genre,
                runtime: runtime,
                standardizedId: standardizedId
            )
            
            // Save to Firestore - using manual encoding
            let movieData = try Firestore.Encoder().encode(movie)
            
            // Simple save to Firestore without simulator-specific error handling
            let docRef = try await db.collection("movies").addDocument(data: movieData)
            print("✅ Movie saved with ID: \(docRef.documentID)")
            let movieId = docRef.documentID
            
            // Update user stats
            try await updateUserStats(userId: userId, type: .movie)
            
            // Create post
            let subtitleText = director ?? (year != nil ? "\(year!)" : "")
            try await createPost(
                userId: userId,
                type: .movie,
                itemId: movieId,
                title: title,
                subtitle: subtitleText,
                location: location,
                review: review,
                rating: rating,
                weekNumber: weekNumber,
                standardizedId: standardizedId
            )
            
            // Get movie with document ID
            var movieWithId = movie
            movieWithId.id = movieId
            return movieWithId
        } catch {
            print("🔴 Error adding movie: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func getMoviesForUser(userId: String, limit: Int? = nil) async throws -> [Movie] {
        do {
            var query = db.collection("movies")
                .whereField("userId", isEqualTo: userId)
                .order(by: "watchedAt", descending: true)
            
            if let limit = limit {
                query = query.limit(to: limit)
            }
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { document in
                do {
                    var movie = try Firestore.Decoder().decode(Movie.self, from: document.data())
                    movie.id = document.documentID
                    return movie
                } catch {
                    print("Error decoding movie: \(error)")
                    return nil
                }
            }
        } catch {
            throw DatabaseError.fetchError
        }
    }
    
    // MARK: - Feed Posts
    
    private func createPost(userId: String, type: PostType, itemId: String, title: String, subtitle: String?, location: String?, review: String?, rating: Int?, weekNumber: Int, standardizedId: String? = nil) async throws {
        do {
            print("🔄 Creating post for \(type): \(title), user: \(userId)")
            
            // Get user data for the post
            print("👤 Fetching user data for post...")
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else {
                print("🔴 User data not found for ID: \(userId)")
                throw DatabaseError.saveError
            }
            
            print("✅ User data fetched. Creating post object...")
            let post = Post(
                userId: userId,
                username: userData["username"] as? String ?? "Unknown User",
                type: type,
                itemId: itemId,
                title: title,
                subtitle: subtitle,
                location: location,
                review: review,
                rating: rating,
                createdAt: Date(),
                weekNumber: weekNumber,
                standardizedId: standardizedId
            )
            
            // Save to Firestore - using manual encoding
            print("💾 Encoding post data...")
            let postData = try Firestore.Encoder().encode(post)
            
            print("📤 Saving post to Firestore...")
            let postRef = try await db.collection("posts").addDocument(data: postData)
            print("✅ Post created with ID: \(postRef.documentID)")
        } catch let error as NSError {
            print("🔴 Error creating post: \(error.localizedDescription)")
            print("🔴 Error domain: \(error.domain), code: \(error.code)")
            print("🔴 Error details: \(error.userInfo)")
            throw DatabaseError.saveError
        }
    }
    
    func getFeedPosts(userId: String, limit: Int = 30) async throws -> [Post] {
        do {
            print("📊 Getting feed posts for user: \(userId), limit: \(limit)")
            
            // Get user's following list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data(), let following = userData["following"] as? [String] else {
                print("⚠️ No following data found, returning user's own posts")
                // If no following, just return the user's own posts
                return try await getUserPosts(userId: userId, limit: limit)
            }
            
            print("👥 User is following \(following.count) people")
            
            // Combine the user's ID with their following for the feed
            var userIds = following
            userIds.append(userId)
            
            // Query posts from followed users and self
            print("🔍 Querying posts from \(userIds.count) users")
            let snapshot = try await db.collection("posts")
                .whereField("userId", in: userIds)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            print("✅ Query returned \(snapshot.documents.count) posts")
            
            return snapshot.documents.compactMap { document in
                do {
                    var post = try Firestore.Decoder().decode(Post.self, from: document.data())
                    post.id = document.documentID
                    return post
                } catch {
                    print("🔴 Error decoding post: \(error)")
                    return nil
                }
            }
        } catch {
            print("🔴 Error in getFeedPosts: \(error.localizedDescription)")
            throw DatabaseError.fetchError
        }
    }
    
    func getUserPosts(userId: String, limit: Int = 10) async throws -> [Post] {
        do {
            print("📊 Getting user posts for user: \(userId), limit: \(limit)")
            
            let snapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            print("✅ Query returned \(snapshot.documents.count) user posts")
            
            return snapshot.documents.compactMap { document in
                do {
                    var post = try Firestore.Decoder().decode(Post.self, from: document.data())
                    post.id = document.documentID
                    return post
                } catch {
                    print("🔴 Error decoding user post: \(error)")
                    return nil
                }
            }
        } catch {
            print("🔴 Error in getUserPosts: \(error.localizedDescription)")
            throw DatabaseError.fetchError
        }
    }
    
    // MARK: - User Stats
    
    private func updateUserStats(userId: String, type: PostType) async throws {
        do {
            let batch = db.batch()
            let userRef = db.collection("users").document(userId)
            
            // Update weekly and total counters
            if type == .beer {
                batch.updateData([
                    "currentWeekBeers": FieldValue.increment(Int64(1)),
                    "totalBeers": FieldValue.increment(Int64(1))
                ], forDocument: userRef)
            } else {
                batch.updateData([
                    "currentWeekMovies": FieldValue.increment(Int64(1)),
                    "totalMovies": FieldValue.increment(Int64(1))
                ], forDocument: userRef)
            }
            
            try await batch.commit()
        } catch {
            throw DatabaseError.updateError
        }
    }
    
    // MARK: - Week Calculation
    
    private func getCurrentWeekData(userId: String, type: PostType) async throws -> (Date, Int) {
        // Calculate current week start date
        let currentWeekStart = getStartOfCurrentWeek()
        
        // Query items for the current week to get the count
        let collectionName = type == .beer ? "beers" : "movies"
        let snapshot = try await db.collection(collectionName)
            .whereField("userId", isEqualTo: userId)
            .whereField("weekStartDate", isEqualTo: currentWeekStart)
            .getDocuments()
        
        // Week number is the count + 1
        let weekNumber = snapshot.documents.count + 1
        
        return (currentWeekStart, weekNumber)
    }
    
    private func getStartOfCurrentWeek() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekStart = calendar.date(from: components)!
        
        // Our weeks start on Sunday, not Monday
        components = calendar.dateComponents([.weekday], from: weekStart)
        let weekday = components.weekday!
        
        // Adjust if needed
        if weekday != 1 { // 1 is Sunday in Gregorian calendar
            return calendar.date(byAdding: .day, value: 1 - weekday, to: weekStart)!
        }
        
        return weekStart
    }
    
    private func formatDateTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Popular Suggestions
    
    func getPopularMovieSuggestions(query: String, limit: Int = 5) async -> [String] {
        do {
            // Convert query to lowercase for case-insensitive search
            let lowercaseQuery = query.lowercased()
            
            // Query the movies collection for titles that start with or contain the query
            let snapshot = try await db.collection("movies")
                .whereField("title", isGreaterThanOrEqualTo: query)
                .whereField("title", isLessThanOrEqualTo: query + "\u{f8ff}") // Unicode character for end of string
                .limit(to: limit)
                .getDocuments()
            
            // Process the results
            var titleCounts: [String: Int] = [:]
            snapshot.documents.forEach { document in
                if let title = document.data()["title"] as? String {
                    titleCounts[title, default: 0] += 1
                }
            }
            
            // Sort by count (popularity) and return titles
            let sortedTitles = titleCounts.sorted { $0.value > $1.value }.map { $0.key }
            return sortedTitles
        } catch {
            print("Error getting popular movie suggestions: \(error.localizedDescription)")
            return []
        }
    }
    
    func getPopularBeerSuggestions(query: String, limit: Int = 5) async -> [String] {
        do {
            // Convert query to lowercase for case-insensitive search
            let lowercaseQuery = query.lowercased()
            
            // Query the beers collection for names that start with or contain the query
            let snapshot = try await db.collection("beers")
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}") // Unicode character for end of string
                .limit(to: limit)
                .getDocuments()
            
            // Process the results
            var nameCounts: [String: Int] = [:]
            snapshot.documents.forEach { document in
                if let name = document.data()["name"] as? String {
                    nameCounts[name, default: 0] += 1
                }
            }
            
            // Sort by count (popularity) and return names
            let sortedNames = nameCounts.sorted { $0.value > $1.value }.map { $0.key }
            return sortedNames
        } catch {
            print("Error getting popular beer suggestions: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Post Interactions (Likes and Comments)
    
    func likePost(postId: String, userId: String) async throws {
        do {
            print("👍 Liking post: \(postId) by user: \(userId)")
            
            // Check if the user already liked this post
            let existingLikes = try await db.collection("interactions")
                .whereField("postId", isEqualTo: postId)
                .whereField("userId", isEqualTo: userId)
                .whereField("type", isEqualTo: "like")
                .getDocuments()
            
            // If already liked, return early (to prevent duplicate likes)
            if !existingLikes.documents.isEmpty {
                print("⚠️ User already liked this post")
                return
            }
            
            // Create the like interaction
            let like = PostInteraction(
                postId: postId,
                userId: userId,
                type: .like,
                text: nil,
                createdAt: Date()
            )
            
            // Save to Firestore
            let likeData = try Firestore.Encoder().encode(like)
            let _ = try await db.collection("interactions").addDocument(data: likeData)
            print("✅ Like saved")
            
            // Create notification for post owner
            // First, get the post to find the owner
            let postDoc = try await db.collection("posts").document(postId).getDocument()
            if let postData = postDoc.data(),
               let postOwnerId = postData["userId"] as? String,
               let postTitle = postData["title"] as? String {
                
                // Get current user's username
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data(),
                   let username = userData["username"] as? String {
                    
                    // Create notification
                    try await createNotification(
                        recipientId: postOwnerId,
                        senderId: userId,
                        senderUsername: username,
                        type: .like,
                        postId: postId,
                        postTitle: postTitle
                    )
                }
            }
        } catch {
            print("🔴 Error liking post: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        do {
            print("👎 Unliking post: \(postId) by user: \(userId)")
            
            // Find the like document
            let snapshot = try await db.collection("interactions")
                .whereField("postId", isEqualTo: postId)
                .whereField("userId", isEqualTo: userId)
                .whereField("type", isEqualTo: "like")
                .getDocuments()
            
            // If no like found, return early
            guard let likeDoc = snapshot.documents.first else {
                print("⚠️ No like found to remove")
                return
            }
            
            // Delete the like document
            try await db.collection("interactions").document(likeDoc.documentID).delete()
            print("✅ Like removed")
        } catch {
            print("🔴 Error unliking post: \(error.localizedDescription)")
            throw DatabaseError.deleteError
        }
    }
    
    func addComment(postId: String, userId: String, text: String) async throws -> PostInteraction {
        do {
            print("💬 Adding comment to post: \(postId) by user: \(userId)")
            
            // Create the comment interaction
            let comment = PostInteraction(
                postId: postId,
                userId: userId,
                type: .comment,
                text: text,
                createdAt: Date()
            )
            
            // Save to Firestore
            let commentData = try Firestore.Encoder().encode(comment)
            let docRef = try await db.collection("interactions").addDocument(data: commentData)
            print("✅ Comment saved with ID: \(docRef.documentID)")
            
            // Create notification for post owner
            // First, get the post to find the owner
            let postDoc = try await db.collection("posts").document(postId).getDocument()
            if let postData = postDoc.data(),
               let postOwnerId = postData["userId"] as? String,
               let postTitle = postData["title"] as? String {
                
                // Get current user's username
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data(),
                   let username = userData["username"] as? String {
                    
                    // Create notification
                    try await createNotification(
                        recipientId: postOwnerId,
                        senderId: userId,
                        senderUsername: username,
                        type: .comment,
                        postId: postId,
                        postTitle: postTitle,
                        commentText: text
                    )
                }
            }
            
            // Return the comment with ID
            var commentWithId = comment
            commentWithId.id = docRef.documentID
            return commentWithId
        } catch {
            print("🔴 Error adding comment: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func getPostInteractions(postId: String) async throws -> (likes: Int, comments: [PostInteraction]) {
        do {
            print("🔍 Getting interactions for post: \(postId)")
            
            // Get all interactions for this post
            let snapshot = try await db.collection("interactions")
                .whereField("postId", isEqualTo: postId)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            // Count likes and collect comments
            var likeCount = 0
            var comments: [PostInteraction] = []
            
            for document in snapshot.documents {
                do {
                    var interaction = try Firestore.Decoder().decode(PostInteraction.self, from: document.data())
                    interaction.id = document.documentID
                    
                    if interaction.type == .like {
                        likeCount += 1
                    } else if interaction.type == .comment {
                        comments.append(interaction)
                    }
                } catch {
                    print("🔴 Error decoding interaction: \(error)")
                }
            }
            
            print("✅ Found \(likeCount) likes and \(comments.count) comments")
            return (likeCount, comments)
        } catch {
            print("🔴 Error getting post interactions: \(error.localizedDescription)")
            throw DatabaseError.fetchError
        }
    }
    
    // MARK: - Notifications
    
    func createNotification(recipientId: String, senderId: String, senderUsername: String, type: NotificationType, postId: String? = nil, postTitle: String? = nil, commentText: String? = nil) async throws {
        do {
            print("📢 Creating notification: \(type.rawValue) for user: \(recipientId)")
            
            // Don't notify users about their own actions
            if recipientId == senderId {
                print("⚠️ Skipping self-notification")
                return
            }
            
            // Create notification object
            let notification = Notification(
                recipientId: recipientId,
                senderId: senderId,
                senderUsername: senderUsername,
                type: type,
                postId: postId,
                postTitle: postTitle,
                commentText: commentText,
                createdAt: Date(),
                isRead: false
            )
            
            // Save to Firestore
            let notificationData = try Firestore.Encoder().encode(notification)
            let docRef = try await db.collection("notifications").addDocument(data: notificationData)
            print("✅ Notification created with ID: \(docRef.documentID)")
        } catch {
            print("🔴 Error creating notification: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func getNotifications(userId: String, limit: Int = 30) async throws -> [Notification] {
        do {
            print("🔍 Getting notifications for user: \(userId)")
            
            let snapshot = try await db.collection("notifications")
                .whereField("recipientId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            print("✅ Query returned \(snapshot.documents.count) notifications")
            
            return snapshot.documents.compactMap { document in
                do {
                    var notification = try Firestore.Decoder().decode(Notification.self, from: document.data())
                    notification.id = document.documentID
                    return notification
                } catch {
                    print("🔴 Error decoding notification: \(error)")
                    return nil
                }
            }
        } catch {
            print("🔴 Error in getNotifications: \(error.localizedDescription)")
            throw DatabaseError.fetchError
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        do {
            print("📝 Marking notification as read: \(notificationId)")
            
            try await db.collection("notifications").document(notificationId).updateData([
                "isRead": true
            ])
            
            print("✅ Notification marked as read")
        } catch {
            print("🔴 Error marking notification as read: \(error.localizedDescription)")
            throw DatabaseError.updateError
        }
    }
    
    func markAllNotificationsAsRead(userId: String) async throws {
        do {
            print("📝 Marking all notifications as read for user: \(userId)")
            
            // Get all unread notifications for this user
            let snapshot = try await db.collection("notifications")
                .whereField("recipientId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            // Create a batch update
            let batch = db.batch()
            for document in snapshot.documents {
                batch.updateData(["isRead": true], forDocument: document.reference)
            }
            
            // Commit the batch
            try await batch.commit()
            
            print("✅ Marked \(snapshot.documents.count) notifications as read")
        } catch {
            print("🔴 Error marking all notifications as read: \(error.localizedDescription)")
            throw DatabaseError.updateError
        }
    }
    
    func getUnreadNotificationCount(userId: String) async throws -> Int {
        do {
            print("🔢 Getting unread notification count for user: \(userId)")
            
            let snapshot = try await db.collection("notifications")
                .whereField("recipientId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            let count = snapshot.documents.count
            print("✅ User has \(count) unread notifications")
            return count
        } catch {
            print("🔴 Error getting unread notification count: \(error.localizedDescription)")
            throw DatabaseError.fetchError
        }
    }
} 