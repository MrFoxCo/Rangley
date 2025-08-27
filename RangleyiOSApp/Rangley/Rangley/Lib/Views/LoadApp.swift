import SwiftUI

struct LoadApp: View {
    var body: some View {
        VStack {
            Spacer()
            
            // Logo
            Image("RangleySticker")
                .resizable()
                .frame(width: 220, height: 220)
                .shadow(color: Color(hex: "#000000").opacity(0.6), radius: 25) // subtle cream glow
            
            Spacer()
            
            // Custom Progress Indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C60C30"))) // Cubs red
                .scaleEffect(1.4)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "000000"),
                    Color(hex: "#000000")
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

// Hex Color Extension
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}
