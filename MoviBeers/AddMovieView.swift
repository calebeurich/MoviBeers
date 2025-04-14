//
//  AddMovieView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import PhotosUI

struct AddMovieView: View {
    @StateObject private var viewModel = AddMovieViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var photoPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Use extracted components for each section
                MovieInfoSection(viewModel: viewModel)
                MovieRatingSection(rating: $viewModel.rating)
                MovieNotesSection(notes: $viewModel.notes)
                MoviePhotoSection(
                    selectedImage: $viewModel.selectedImage,
                    photoPickerItem: $photoPickerItem
                )
                AddMovieButtonSection(
                    isLoading: viewModel.isLoading,
                    authViewModel: authViewModel,
                    addMovie: viewModel.addMovie
                )
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "Movie added successfully!")
            }
            .onChange(of: photoPickerItem) { newValue in
                if let newItem = newValue {
                    loadTransferableImage(from: newItem)
                }
            }
        }
    }
    
    // Helper function to load image from PhotosPickerItem
    private func loadTransferableImage(from item: PhotosPickerItem) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.selectedImage = image
                        }
                    }
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
}

// MARK: - Movie Info Section
struct MovieInfoSection: View {
    @ObservedObject var viewModel: AddMovieViewModel
    
    var body: some View {
        Section("Movie Info") {
            TextField("Movie Title", text: $viewModel.title)
                .onChange(of: viewModel.title) { _ in
                    viewModel.standardizeTitle()
                    viewModel.searchPopularMovies()
                }
            
            // Show standardized title if there is one and standardization is enabled
            if !viewModel.standardizedTitle.isEmpty && viewModel.standardizedTitle != viewModel.title && viewModel.shouldStandardizeTitle {
                HStack {
                    Text("Will be saved as: ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.standardizedTitle)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            // Toggle for title standardization
            Toggle("Standardize title format", isOn: $viewModel.shouldStandardizeTitle)
                .onChange(of: viewModel.shouldStandardizeTitle) { _ in
                    viewModel.standardizeTitle()
                }
            
            // Show popular suggestions if available
            if !viewModel.popularSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Text("Popular:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        ForEach(viewModel.popularSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                viewModel.selectSuggestion(suggestion)
                            }) {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            TextField("Director (Optional)", text: $viewModel.director)
            TextField("Year (Optional)", text: $viewModel.year)
                .keyboardType(.numberPad)
        }
    }
}

// MARK: - Rating Section
struct MovieRatingSection: View {
    @Binding var rating: Double
    
    var body: some View {
        Section("Rating") {
            VStack {
                Text("Rating: \(Int(rating))/5")
                
                HStack {
                    Text("1")
                    Slider(value: $rating, in: 1...5, step: 1)
                    Text("5")
                }
                
                // Star display
                HStack {
                    ForEach(1..<6) { star in
                        Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Notes Section
struct MovieNotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        Section("Notes (Optional)") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
}

// MARK: - Photo Section
struct MoviePhotoSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var photoPickerItem: PhotosPickerItem?
    
    var body: some View {
        Section("Photo (Optional)") {
            // Photo picker button
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                    Text(selectedImage == nil ? "Add Photo" : "Change Photo")
                }
            }
            
            // Show selected image preview
            if let image = selectedImage {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                    
                    Button(role: .destructive) {
                        selectedImage = nil
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - Add Movie Button Section
struct AddMovieButtonSection: View {
    let isLoading: Bool
    let authViewModel: AuthViewModel
    let addMovie: (String) -> Void
    
    var body: some View {
        Section {
            Button {
                if let userId = authViewModel.user?.id {
                    addMovie(userId)
                }
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Add Movie")
                    }
                    Spacer()
                }
            }
            .disabled(isLoading)
        }
    }
}

#Preview {
    NavigationStack {
        AddMovieView()
            .environmentObject(AuthViewModel())
    }
} 