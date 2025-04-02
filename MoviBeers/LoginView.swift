//
//  LoginView.swift
//  MoviBeers
//
//  Created by Caleb Eurich on 4/2/25.
//

import SwiftUI
import FirebaseFirestore

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var username = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                // App logo and name
                VStack(spacing: 15) {
                    Image(systemName: "film.stack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("MoviBeers")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Track your movies & beers weekly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 20) {
                    if isSignUp {
                        // Username field for signup
                        TextField("Username", text: $username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Email field
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    // Error message if any
                    if let error = authViewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Sign in/up button
                    Button(action: {
                        if isSignUp {
                            if !username.isEmpty {
                                // Validate email
                                if !isValidEmail(email) {
                                    authViewModel.error = "Please enter a valid email address."
                                    return
                                }
                                
                                // Validate password
                                if password.count < 6 {
                                    authViewModel.error = "Password must be at least 6 characters."
                                    return
                                }
                                
                                print("Validation passed, attempting sign up...")
                                authViewModel.signUp(email: email, password: password, username: username)
                            } else {
                                showingAlert = true
                            }
                        } else {
                            authViewModel.signIn(email: email, password: password)
                        }
                    }) {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    
                    // Toggle between sign in and sign up
                    Button(action: {
                        isSignUp.toggle()
                        authViewModel.error = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    // Debug button to verify Firebase connection
                    #if DEBUG
                    Button(action: {
                        testFirebaseConnection()
                    }) {
                        Text("Test Firebase Connection")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                    }
                    #endif
                }
                .padding(.horizontal)
                
                Spacer()
                
                // App description
                VStack(spacing: 8) {
                    Text("Challenge: 20 beers & 3 movies per week")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("Track, share, and compete with friends!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Missing Information"),
                    message: Text("Please provide a username."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func testFirebaseConnection() {
        print("🔍 Testing Firebase connection...")
        let db = Firestore.firestore()
        
        Task {
            do {
                try await db.collection("test").document("connection")
                    .setData(["timestamp": FieldValue.serverTimestamp()])
                print("✅ Firebase connection test successful!")
            } catch {
                print("🔴 Firebase connection failed: \(error.localizedDescription)")
            }
        }
        
        print("📱 Device info: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
} 