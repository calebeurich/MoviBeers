//
//  AddBeerView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import PhotosUI

struct AddBeerView: View {
    @StateObject private var viewModel = AddBeerViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var photoPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Beer Info Section
                Section("Beer Info") {
                    TextField("Beer Name", text: $viewModel.name)
                        .onChange(of: viewModel.name) { _ in
                            viewModel.searchBeers()
                        }
                    
                    // Show suggestions if available
                    if !viewModel.beerSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.beerSuggestions) { suggestion in
                                    BeerSuggestionCard(
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
                            Text("Using standardized beer: \(suggestion.name)")
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
                    
                    TextField("Brand", text: $viewModel.brand)
                    TextField("Type (Optional)", text: $viewModel.type)
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
                                    .foregroundColor(.yellow)
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
                    // Photo picker
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(viewModel.selectedImage == nil ? "Add Photo" : "Change Photo")
                        }
                    }
                    
                    // Show selected image preview
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
                    }
                }
                
                // MARK: - Add Button
                Section {
                    Button {
                        guard let userId = authViewModel.currentUser?.id else { return }
                        viewModel.addBeer(userId: userId)
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Add Beer")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Add Beer")
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
                Text(viewModel.successMessage ?? "Beer added successfully!")
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

// MARK: - Beer Suggestion Card

struct BeerSuggestionCard: View {
    let suggestion: BeerSuggestion
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(suggestion.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let type = suggestion.type {
                    Text(type)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(width: 130)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    NavigationStack {
        AddBeerView()
            .environmentObject(AuthViewModel())
    }
} 