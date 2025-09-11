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


struct SignInView: View {
    let onAuthenticated: () -> Void
    @State private var isBusy = false

    var body: some View {
        ZStack {
            // Black → Russian violet (#2E003E). Swap the array to flip direction.
            LinearGradient(
                gradient: Gradient(colors: [.black, Color(hex: "#2E003E")]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()
                    Image("RangleySticker")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)

                    Button {
                        Task {
                            guard !isBusy else { return }
                            isBusy = true; defer { isBusy = false }
                            onAuthenticated()
                        }
                    } label: {
                        HStack {
                            if isBusy { ProgressView() }
                            Text(isBusy ? "Signing in…" : "Sign In").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.Purples.pigNeonPink)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .background(AppPalette.Purples.pigNeonPink, in: Capsule())

                    Spacer()

                    NavigationLink {
                        UserRegisterFlow()
                    } label: {
                        Text("Create new account")
                            .font(.headline.weight(.semibold))
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#2E003E"), in: Capsule())
                            .foregroundStyle(.white)
                            .shadow(radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Welcome").font(.headline).foregroundStyle(.white)
                    }
                }
                // Make sure the nav bar doesn’t cover the gradient
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { SignInView(onAuthenticated: {}) }
