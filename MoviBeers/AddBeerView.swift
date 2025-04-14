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
                // Use extracted components for each section
                BeerInfoSection(viewModel: viewModel)
                BeerRatingSection(rating: $viewModel.rating)
                BeerNotesSection(notes: $viewModel.notes)
                PhotoSection(
                    selectedImage: $viewModel.selectedImage,
                    photoPickerItem: $photoPickerItem
                )
                AddBeerButtonSection(
                    isLoading: viewModel.isLoading,
                    authViewModel: authViewModel,
                    addBeer: viewModel.addBeer
                )
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

// MARK: - Beer Info Section
struct BeerInfoSection: View {
    @ObservedObject var viewModel: AddBeerViewModel
    
    var body: some View {
        Section("Beer Info") {
            TextField("Beer Name", text: $viewModel.name)
                .onChange(of: viewModel.name) { _ in
                    viewModel.standardizeBeerName()
                    viewModel.searchPopularBeers()
                }
            
            // Show standardized name if there is one and standardization is enabled
            if !viewModel.standardizedName.isEmpty && viewModel.standardizedName != viewModel.name && viewModel.shouldStandardizeName {
                HStack {
                    Text("Will be saved as: ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.standardizedName)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            // Toggle for beer name standardization
            Toggle("Standardize beer name", isOn: $viewModel.shouldStandardizeName)
                .onChange(of: viewModel.shouldStandardizeName) { _ in
                    viewModel.standardizeBeerName()
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
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            TextField("Size (e.g., 12oz, Pint)", text: $viewModel.size)
            
            TextField("Type (Optional)", text: $viewModel.type)
        }
    }
}

// MARK: - Rating Section
struct BeerRatingSection: View {
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
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }
}

// MARK: - Notes Section
struct BeerNotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        Section("Notes (Optional)") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
}

// MARK: - Photo Section
struct PhotoSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var photoPickerItem: PhotosPickerItem?
    
    var body: some View {
        Section("Photo (Optional)") {
            // Photo picker
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                    Text(selectedImage == nil ? "Add Photo" : "Change Photo")
                }
            }
            
            // Show selected image preview
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
            }
        }
    }
}

// MARK: - Add Beer Button Section
struct AddBeerButtonSection: View {
    let isLoading: Bool
    let authViewModel: AuthViewModel
    let addBeer: (String) -> Void
    
    var body: some View {
        Section {
            Button {
                if let userId = authViewModel.user?.id {
                    addBeer(userId)
                }
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Add Beer")
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
        AddBeerView()
            .environmentObject(AuthViewModel())
    }
} 