//
//  SignIn.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//



// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW
// TODO: - Setup AWS End User Messaging
// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================



import SwiftUI
import Amplify

extension Color
{
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
    @EnvironmentObject private var auth: AuthStateStore
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Content Area
                VStack(spacing: 32) {
                    Spacer()

                    // Logo
                    Image("RangleySticker")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Buttons
                    VStack(spacing: 16) {
                        NavigationLink {
                            UserRegisterFlow()
                        } label: {
                            Text("Create new account")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CreateNewAccountCapsuleButton(font: FontStyles.headline))

                        NavigationLink {
                            LogInPageView()
                        } label: {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutlineCapsuleButton(font: FontStyles.title1))
                    }
                    .padding(.horizontal, 32) // Consistent, safe padding

                    Spacer()
                }
                .padding(.vertical, 40) // Give breathing room top/bottom

                // Bottom Branding – RESPONSIVE
                Image("MrFoxOrange")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
            .background(AppPalette.bgGradient.ignoresSafeArea())
        }
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
