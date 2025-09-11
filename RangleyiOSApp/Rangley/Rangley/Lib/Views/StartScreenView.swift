//
//  SignIn.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

import SwiftUI
import Amplify

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")
        var v: UInt64 = 0; _ = Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6: (r,g,b,a) = (Double((v>>16)&0xFF)/255, Double((v>>8)&0xFF)/255, Double(v&0xFF)/255, 1)
        case 8: (r,g,b,a) = (Double((v>>24)&0xFF)/255, Double((v>>16)&0xFF)/255, Double((v>>8)&0xFF)/255, Double(v&0xFF)/255)
        default: (r,g,b,a) = (0,0,0,1)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}


struct StartScreenView: View
{
    let onAuthenticated: () -> Void
    @State private var isBusy = false

    var body: some View
    {
        NavigationStack {
            VStack(spacing: 24)
            {
                Spacer()
                Image("RangleySticker")
                    .resizable().scaledToFit().frame(width: 200, height: 200)
                
                let neonPink = AppPalette.Brand.neonPink

                NavigationLink {
                    LogInPageView()
                } label: {
                    HStack {
                        Text("Log In").font(.system(size: 25, weight: .semibold))
                    }

                }
                .padding(.horizontal, 20)
                .buttonStyle(OutlineCapsuleButton(color: neonPink))
                // ensure text is neon

                Spacer()

                NavigationLink {
                    UserRegisterNoCodeFlow()
                } label: {
                    Text("Create new account")
                        .font(.system(size: 18, weight: .semibold))     // slightly smaller
                        .kerning(0.2)
                        .foregroundStyle(.white.opacity(0.98))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [AppPalette.Brand.violetMid.opacity(0.98),
                                             AppPalette.Brand.russianViolet.opacity(0.98)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)


            }
            .padding(.horizontal, 16)
            // We don't want title
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    Text("Welcome").font(.headline).foregroundStyle(.white)
//                }
//            }
            .background(AppPalette.bgGradient.ignoresSafeArea()) 
        }
        // <- THIS is what makes it show
        .toolbarBackground(.clear, for: .navigationBar)  // keep the bar transparent
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}


#Preview { StartScreenView(onAuthenticated: {}) }
