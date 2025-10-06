//
//  IconStyles.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/6/25.
//

import SwiftUI

func iconColor(for icon: String) -> Color
{
    switch icon {
    case "basketball.fill":
        return .orange
    case "football.fill":
        return .brown
    case "fork.knife":
        return .gray
    case "book.fill":
        return .blue
    case "figure.run":
        return .cyan
    case "gamecontroller.fill":
        return .purple
    case "music.note":
        return .pink
    case "airplane":
        return .blue
    case "cup.and.saucer.fill":
        return .brown
    case "film.fill":
        return .red
    case "paintbrush.fill":
        return .purple
    case "leaf.fill":
        return .green
    case "brain.head.profile":
        return .pink
    case "heart.fill":
        return .red
    case "wineglass.fill":
        return Color(red: 0.5, green: 0.0, blue: 0.3)
    case "tennis.racket":
        return .green
    case "person.3.fill":
        return AppPalette.Brand.neonPink
    default:
        return AppPalette.Brand.neonPink
    }
}
