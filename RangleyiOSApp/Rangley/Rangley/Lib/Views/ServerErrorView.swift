//
//  ServerErrorView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import SwiftUI

struct ServerErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("RangleySticker")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                
                Text("Oops!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
                    
                    Button("Continue Without Check") {
                        // Allow users to proceed if server is down
                        // You'll need to pass this action from the parent view
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .foregroundColor(.white)
                }
            }
            .padding()
        }
    }
}

struct NetworkErrorView: View {
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("RangleySticker")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                
                Text("No Connection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Please check your internet connection and try again.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.black)
            }
            .padding()
        }
    }
}
