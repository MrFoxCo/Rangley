//
//  DateSlider.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/9/25.
//
import SwiftUI

public struct DateWheel: View {
    @State private var selectionIndex: Int = 0

    private let timeFrames = [
        "1 Minute",
        "1 Hour",
        "1 Day",
        "1 Week",
        "1 Month",
        "3 Months",
        "1 Year"
    ]

    public var body: some View {
        VStack(spacing: 4) {
            // Label above
            Text(timeFrames[selectionIndex])
                .font(.headline)
                .bold()

            GeometryReader { outerGeometry in
                let itemWidth: CGFloat = 100

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(timeFrames.indices, id: \.self) { index in
                            GeometryReader { itemGeometry in
                                let globalMidX = itemGeometry.frame(in: .global).midX
                                let containerMidX = outerGeometry.frame(in: .global).midX
                                let distance = abs(globalMidX - containerMidX)
                                let isSelected = distance < (itemWidth / 2)

                                Color.clear
                                    .onAppear {
                                        if isSelected {
                                            selectionIndex = index
                                        }
                                    }
                                    .onChange(of: distance) { _, newDistance in
                                        if newDistance < (itemWidth / 2) {
                                            selectionIndex = index
                                        }
                                    }

                                Text(timeFrames[index])
                                    .font(.subheadline)
                                    .bold()
                                    .frame(width: itemWidth)
                                    .scaleEffect(isSelected ? 1.2 : 1.0)
                                    .opacity(isSelected ? 1.0 : 0.4)
                                    .animation(.easeInOut, value: isSelected)
                                    .contentShape(Rectangle())
                            }
                            .frame(width: itemWidth, height: 50)
                        }
                    }
                    .padding(.horizontal, (outerGeometry.size.width - itemWidth) / 2)
                }
            }
            .frame(height: 50) // only the slider height
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DateWheel()
}
