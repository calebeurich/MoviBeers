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
                    photoPickerItem: $photoPickerItem,
                    selectedSuggestion: viewModel.selectedSuggestion
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
                    viewModel.searchMovies()
                }
            
            // Show suggestions if available
            if !viewModel.movieSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.movieSuggestions) { suggestion in
                            MovieSuggestionCard(
                                suggestion: suggestion,
                                isSelected: viewModel.selectedSuggestion?.id == suggestion.id,
                                onSelect: {
                                    viewModel.selectSuggestion(suggestion)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            // Loading indicator
            if viewModel.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            
            // Selected suggestion badge
            if let suggestion = viewModel.selectedSuggestion {
                HStack {
                    Text("Using standardized movie: \(suggestion.title)")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearSelection()
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
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
    let selectedSuggestion: MovieSuggestion?
    
    var body: some View {
        Section("Photo (Optional)") {
            // Photo picker button
            // Only show if there's no suggestion with an image or if the user wants a custom image
            if selectedSuggestion?.imageURL == nil || selectedImage != nil {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text(selectedImage == nil ? "Add Photo" : "Change Photo")
                    }
                }
            }
            
            // Show selected image preview (either from suggestion or user selection)
            if let image = selectedImage {
                HStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                    Spacer()
                }
                
                Button(role: .destructive) {
                    selectedImage = nil
                    photoPickerItem = nil
                } label: {
                    HStack {
                        Spacer()
                        Text("Remove Photo")
                        Spacer()
                    }
                }
            } else if let suggestion = selectedSuggestion, let imageURL = suggestion.imageURL {
                VStack {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        case .failure:
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("Poster from TMDB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    // Allow user to add a custom photo instead
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Text("Use Custom Photo Instead")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Add Button Section
struct AddMovieButtonSection: View {
    let isLoading: Bool
    let authViewModel: AuthViewModel
    let addMovie: (String) -> Void
    
    var body: some View {
        Section {
            Button {
                guard let userId = authViewModel.user?.id else { return }
                addMovie(userId)
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Add Movie")
                            .bold()
                    }
                    Spacer()
                }
            }
            .disabled(isLoading)
        }
    }
}

// MARK: - Movie Suggestion Card
struct MovieSuggestionCard: View {
    let suggestion: MovieSuggestion
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                // Movie poster if available
                if let imageURL = suggestion.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 180)
                                .clipped()
                                .cornerRadius(8)
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 120, height: 180)
                } else {
                    // Placeholder if no image
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 180)
                        .overlay(
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                if let year = suggestion.year {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                    .background(isSelected ? Color.red.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
            )
        }
    }
}

#Preview {
    NavigationStack {
        AddMovieView()
            .environmentObject(AuthViewModel())
    }
} 