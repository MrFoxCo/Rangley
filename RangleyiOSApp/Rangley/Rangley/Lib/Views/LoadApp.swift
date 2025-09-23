//
//  RangleApp.swift
//
//  Created by Anthony Guzzardo on 7/10/25.
//


import SwiftUI

struct LoadApp: View {
    var body: some View {
        VStack {
            Spacer()
            
            // Logo
            Image("RangleySticker")
                .resizable()
                .frame(width: 220, height: 220)
                .shadow(color: Color(hex: "#006D77").opacity(0.6), radius: 25) // subtle cream glow
            
            Spacer()
            
            // Custom Progress Indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#006D77"))) // Cubs red
                .scaleEffect(1.4)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#0A719D"),
                    Color(hex: "#7557C7")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // transition logic
                }
            }
        }
    }
}
