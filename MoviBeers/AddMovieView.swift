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
                // MARK: - Movie Info Section
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
                
                // MARK: - Rating Section
                Section("Rating") {
                    VStack {
                        Text("Rating: \(Int(viewModel.rating))/5")
                        
                        HStack {
                            Text("1")
                            Slider(value: $viewModel.rating, in: 1...5, step: 1)
                            Text("5")
                        }
                        
                        // Star display
                        HStack {
                            ForEach(1..<6) { star in
                                Image(systemName: star <= Int(viewModel.rating) ? "star.fill" : "star")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // MARK: - Notes Section
                Section("Notes (Optional)") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 100)
                }
                
                // MARK: - Photo Section
                Section("Photo (Optional)") {
                    // Photo picker button
                    // Only show if there's no suggestion with an image or if the user wants a custom image
                    if viewModel.selectedSuggestion?.imageURL == nil || viewModel.selectedImage != nil {
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text(viewModel.selectedImage == nil ? "Add Photo" : "Change Photo")
                            }
                        }
                    }
                    
                    // Show selected image preview (either from suggestion or user selection)
                    if let image = viewModel.selectedImage {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                            Spacer()
                        }
                        
                        Button(role: .destructive) {
                            viewModel.selectedImage = nil
                            photoPickerItem = nil
                        } label: {
                            HStack {
                                Spacer()
                                Text("Remove Photo")
                                Spacer()
                            }
                        }
                    } else if let suggestion = viewModel.selectedSuggestion, let imageURL = suggestion.imageURL {
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
                
                // MARK: - Add Button
                Section {
                    Button {
                        guard let userId = authViewModel.currentUser?.id else { return }
                        viewModel.addMovie(userId: userId)
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Add Movie")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
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
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.selectedImage = image
                        }
                    }
                }
            }
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