//
//  StorageService.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import Foundation
import FirebaseStorage
import UIKit

enum StorageError: Error {
    case uploadError
    case downloadError
    case invalidImage
}

class StorageService {
    private let storage = Storage.storage().reference()
    
    func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
        do {
            print("Uploading profile image for user: \(userId)")
            // Resize image for profile
            guard let resizedImage = image.resized(to: CGSize(width: 300, height: 300)),
                  let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
                print("🔴 Error: Invalid image or failed to resize")
                throw StorageError.invalidImage
            }
            
            // Path in Firebase Storage
            let path = "profile_images/\(userId)_\(UUID().uuidString).jpg"
            let reference = storage.child(path)
            
            // Upload image
            _ = try await reference.putDataAsync(imageData)
            print("✅ Image uploaded to path: \(path)")
            
            // Get download URL
            let downloadURL = try await reference.downloadURL()
            print("✅ Download URL obtained: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("🔴 Error uploading profile image: \(error.localizedDescription)")
            throw StorageError.uploadError
        }
    }
    
    func uploadPostImage(userId: String, type: String, image: UIImage) async throws -> String {
        do {
            print("Uploading \(type) image for user: \(userId)")
            // Resize image for post
            guard let resizedImage = image.resized(to: CGSize(width: 800, height: 800)),
                  let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
                print("🔴 Error: Invalid image or failed to resize")
                throw StorageError.invalidImage
            }
            
            // Path in Firebase Storage
            let path = "\(type)_images/\(userId)_\(UUID().uuidString).jpg"
            let reference = storage.child(path)
            
            // Upload image
            _ = try await reference.putDataAsync(imageData)
            print("✅ Image uploaded to path: \(path)")
            
            // Get download URL
            let downloadURL = try await reference.downloadURL()
            print("✅ Download URL obtained: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("🔴 Error uploading post image: \(error.localizedDescription)")
            throw StorageError.uploadError
        }
    }
    
    func deleteImage(url: String) async throws {
        do {
            print("Attempting to delete image at URL: \(url)")
            // Extract the path from the URL
            guard let urlObject = URL(string: url),
                  let path = urlObject.path.components(separatedBy: "/o/").last,
                  let decodedPath = path.removingPercentEncoding else {
                print("⚠️ Could not extract path from URL")
                return
            }
            
            // Delete the image
            try await storage.child(decodedPath).delete()
            print("✅ Image deleted successfully")
        } catch {
            print("🔴 Error deleting image: \(error.localizedDescription)")
            throw StorageError.uploadError
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
} 