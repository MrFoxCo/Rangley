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

                NavigationLink {
                    LogInPageView()
                } label: {
                        Text("Log In")
                }
                .buttonStyle(OutlineCapsuleButton(font: FontStyles.title1))
                // ensure text is neon

                Spacer()

                NavigationLink {
                    UserRegisterNoCodeFlow()
                } label: {
                    Text("Create new account")
                }
                .buttonStyle(CreateNewAccountCapsuleButton(font: FontStyles.headline))
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
    }
}


#Preview { StartScreenView(onAuthenticated: {}) }
