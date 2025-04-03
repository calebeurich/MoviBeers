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
    
    func addBeer(userId: String, name: String, brand: String, location: String?, review: String?, rating: Int?, imageURL: String?, type: String?, abv: Double?, standardizedId: String? = nil) async throws -> Beer {
        do {
            print("Adding beer: \(name) for user: \(userId)")
            // Get current week data
            let (weekStartDate, weekNumber) = try await getCurrentWeekData(userId: userId, type: .beer)
            
            // Create beer object
            let beer = Beer(
                userId: userId,
                name: name,
                brand: brand,
                location: location,
                review: review,
                rating: rating,
                consumedAt: Date(),
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                imageURL: imageURL,
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
                subtitle: brand,
                imageURL: imageURL,
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
    
    func addMovie(userId: String, title: String, director: String?, year: Int?, location: String?, review: String?, rating: Int?, posterURL: String?, genre: String?, runtime: Int?, standardizedId: String? = nil) async throws -> Movie {
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
                posterURL: posterURL,
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
                imageURL: posterURL,
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
    
    private func createPost(userId: String, type: PostType, itemId: String, title: String, subtitle: String?, imageURL: String?, location: String?, review: String?, rating: Int?, weekNumber: Int, standardizedId: String? = nil) async throws {
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
                userProfileImage: userData["profileImageURL"] as? String,
                type: type,
                itemId: itemId,
                title: title,
                subtitle: subtitle,
                imageURL: imageURL,
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
} 