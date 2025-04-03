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
            
            // Add special handling for simulator
            var beerId: String = UUID().uuidString // Default fallback ID for simulator
            
            do {
                let docRef = try await db.collection("beers").addDocument(data: beerData)
                print("✅ Beer saved with ID: \(docRef.documentID)")
                beerId = docRef.documentID
                
                // Update user stats - also in try/catch block
                try await updateUserStats(userId: userId, type: .beer)
                
                // Create post - also in try/catch block
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
            } catch let error as NSError {
                // Check if this is the specific AppCheck error in simulator
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
                   UIDevice.current.isSimulator {
                    print("⚠️ Caught expected AppCheck error in simulator when saving beer - continuing with local beer object")
                    print("⚠️ This is only for development in the simulator - the beer is not actually saved to Firestore")
                    
                    // For simulator development only - we'll skip the Firestore operations but return a beer object
                    // so the user can continue using the app
                } else {
                    // For any other error, or on a real device, propagate the error
                    print("🔴 Failed to save beer: \(error.localizedDescription)")
                    throw error
                }
            }
            
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
            
            // Add special handling for simulator
            var movieId: String = UUID().uuidString // Default fallback ID for simulator
            
            do {
                let docRef = try await db.collection("movies").addDocument(data: movieData)
                print("✅ Movie saved with ID: \(docRef.documentID)")
                movieId = docRef.documentID
                
                // Update user stats - also in try/catch block
                try await updateUserStats(userId: userId, type: .movie)
                
                // Create post - also in try/catch block
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
            } catch let error as NSError {
                // Check if this is the specific AppCheck error in simulator
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
                   UIDevice.current.isSimulator {
                    print("⚠️ Caught expected AppCheck error in simulator when saving movie - continuing with local movie object")
                    print("⚠️ This is only for development in the simulator - the movie is not actually saved to Firestore")
                    
                    // For simulator development only - we'll skip the Firestore operations but return a movie object
                    // so the user can continue using the app
                } else {
                    // For any other error, or on a real device, propagate the error
                    print("🔴 Failed to save movie: \(error.localizedDescription)")
                    throw error
                }
            }
            
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
            // Get user data for the post
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data()
            
            let post = Post(
                userId: userId,
                username: userData?["username"] as? String ?? "Unknown User",
                userProfileImage: userData?["profileImageURL"] as? String,
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
            let postData = try Firestore.Encoder().encode(post)
            try await db.collection("posts").addDocument(data: postData)
            print("✅ Post created for \(type): \(title)")
        } catch {
            print("🔴 Error creating post: \(error.localizedDescription)")
            throw DatabaseError.saveError
        }
    }
    
    func getFeedPosts(userId: String, limit: Int = 30) async throws -> [Post] {
        do {
            // Get user's following list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data(), let following = userData["following"] as? [String] else {
                // If no following, just return the user's own posts
                return try await getUserPosts(userId: userId, limit: limit)
            }
            
            // Combine the user's ID with their following for the feed
            var userIds = following
            userIds.append(userId)
            
            // Query posts from followed users and self
            let snapshot = try await db.collection("posts")
                .whereField("userId", in: userIds)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                do {
                    var post = try Firestore.Decoder().decode(Post.self, from: document.data())
                    post.id = document.documentID
                    return post
                } catch {
                    print("Error decoding post: \(error)")
                    return nil
                }
            }
        } catch {
            throw DatabaseError.fetchError
        }
    }
    
    func getUserPosts(userId: String, limit: Int = 10) async throws -> [Post] {
        do {
            let snapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                do {
                    var post = try Firestore.Decoder().decode(Post.self, from: document.data())
                    post.id = document.documentID
                    return post
                } catch {
                    print("Error decoding post: \(error)")
                    return nil
                }
            }
        } catch {
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
        
        #if targetEnvironment(simulator)
        do {
            // Query items for the current week to get the count
            let collectionName = type == .beer ? "beers" : "movies"
            let snapshot = try await db.collection(collectionName)
                .whereField("userId", isEqualTo: userId)
                .whereField("weekStartDate", isEqualTo: currentWeekStart)
                .getDocuments()
            
            // Week number is the count + 1
            let weekNumber = snapshot.documents.count + 1
            
            return (currentWeekStart, weekNumber)
        } catch let error as NSError {
            // Check if this is the specific AppCheck error in simulator
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 &&
               UIDevice.current.isSimulator {
                print("⚠️ Caught expected AppCheck error in simulator when calculating week data")
                print("⚠️ Using default week number 1 for development")
                
                // For development only - default to week 1
                return (currentWeekStart, 1)
            } else {
                print("🔴 Error calculating week data: \(error.localizedDescription)")
                throw DatabaseError.weekCalculationError
            }
        }
        #else
        do {
            // Query items for the current week to get the count
            let collectionName = type == .beer ? "beers" : "movies"
            let snapshot = try await db.collection(collectionName)
                .whereField("userId", isEqualTo: userId)
                .whereField("weekStartDate", isEqualTo: currentWeekStart)
                .getDocuments()
            
            // Week number is the count + 1
            let weekNumber = snapshot.documents.count + 1
            
            return (currentWeekStart, weekNumber)
        } catch {
            throw DatabaseError.weekCalculationError
        }
        #endif
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