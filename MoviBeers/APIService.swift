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
    // MARK: - Beer API
    
    // Using Open Brewery DB API for beer suggestions (free and no API key required)
    // https://www.openbrewerydb.org/
    private let beerBaseURL = "https://api.openbrewerydb.org/v1"
    
    // MARK: - Movie API
    
    // Using TMDB API for movie suggestions (requires API key)
    // https://developer.themoviedb.org/docs
    private let movieBaseURL = "https://api.themoviedb.org/3"
    // Note: In a real app, this should be stored securely, not hardcoded
    // Using a placeholder that would need to be replaced with a real key
    private let tmdbApiKey = "YOUR_TMDB_API_KEY_HERE"
    
    // MARK: - HTTP Client
    
    private let session = URLSession.shared
    private let jsonDecoder = JSONDecoder()
    
    // MARK: - Beer API Methods
    
    func searchBeers(query: String) async throws -> [BeerSuggestion] {
        // If query is too short, return empty results
        guard query.count >= 2 else { return [] }
        
        print("Searching beers with query: \(query)")
        let urlString = "\(beerBaseURL)/breweries/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            print("🔴 Invalid URL for beer search")
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔴 Unknown response type from server")
                throw APIError.unknown
            }
            
            guard httpResponse.statusCode == 200 else {
                print("🔴 Server error: \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            // Decode the brewery data
            jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let breweries = try jsonDecoder.decode([Brewery].self, from: data)
            print("✅ Received \(breweries.count) breweries from API")
            
            // Convert breweries to beer suggestions
            let suggestions = breweries.flatMap { brewery in
                // For each brewery, create a few generic beer suggestions
                let beerTypes = ["IPA", "Lager", "Stout", "Pale Ale", "Pilsner", "Porter"]
                
                return beerTypes.prefix(2).map { beerType in
                    BeerSuggestion(
                        id: "\(brewery.id)_\(beerType.lowercased().replacingOccurrences(of: " ", with: "_"))",
                        name: "\(beerType)",
                        brand: brewery.name,
                        type: beerType,
                        imageURL: nil
                    )
                }
            }
            
            print("✅ Generated \(suggestions.count) beer suggestions")
            return suggestions
        } catch let error as APIError {
            throw error
        } catch {
            print("🔴 Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Movie API Methods
    
    func searchMovies(query: String) async throws -> [MovieSuggestion] {
        // If query is too short, return empty results
        guard query.count >= 2 else { return [] }
        
        print("Searching movies with query: \(query)")
        let urlString = "\(movieBaseURL)/search/movie?api_key=\(tmdbApiKey)&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            print("🔴 Invalid URL for movie search")
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔴 Unknown response type from server")
                throw APIError.unknown
            }
            
            guard httpResponse.statusCode == 200 else {
                print("🔴 Server error: \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            // Decode the movie data
            let tmdbResponse = try jsonDecoder.decode(TMDBSearchResponse.self, from: data)
            print("✅ Received \(tmdbResponse.results.count) movies from API")
            
            // Convert TMDB movies to movie suggestions
            let suggestions = tmdbResponse.results.map { tmdbMovie in
                let releaseYear: Int? = {
                    if let releaseDateString = tmdbMovie.releaseDate, 
                       let year = Int(releaseDateString.prefix(4)) {
                        return year
                    }
                    return nil
                }()
                
                return MovieSuggestion(
                    id: String(tmdbMovie.id),
                    title: tmdbMovie.title,
                    year: releaseYear,
                    imageURL: tmdbMovie.posterPath != nil ? "https://image.tmdb.org/t/p/w200\(tmdbMovie.posterPath!)" : nil
                )
            }
            
            print("✅ Processed \(suggestions.count) movie suggestions")
            return suggestions
        } catch let error as APIError {
            throw error
        } catch {
            print("🔴 Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Model Structs

// Suggestions model for displaying standardized beer options
struct BeerSuggestion: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String
    let type: String?
    let imageURL: String?
}

// Brewery model from Open Brewery DB API
struct Brewery: Codable {
    let id: String
    let name: String
    let breweryType: String?
    let street: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let longitude: String?
    let latitude: String?
    let phone: String?
    let websiteUrl: String?
}

// Suggestions model for displaying standardized movie options
struct MovieSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let year: Int?
    let imageURL: String?
}

// TMDB API response models
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalResults: Int
    let totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
    }
} 