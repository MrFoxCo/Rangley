import SwiftUI

struct ActionBar: View {
    @Binding var isPlacingEvent: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Add button
            Button(action: {
                print("Add MeetUp")
                isPlacingEvent = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
            }

            // Search button
            Button(action: {
                print("Search tapped")
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
            }

            // Menu button
            Button(action: {
                print("Menu tapped")
            }) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(.systemGray5))
        )
        .shadow(radius: 4)
    }
}
#Preview {
    ActionBar(isPlacingEvent: .constant(true))
}
