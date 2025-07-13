// AppColors.swift
// Color palette inspired by your app icon

import SwiftUI

extension Color {
    // Gradient colors
    static let appGradientTop = Color(red: 0.98, green: 0.39, blue: 0.64) // Magenta-Pink
    static let appGradientBottom = Color(red: 0.38, green: 0.33, blue: 0.98) // Blue-Purple

    // Dragon
    static let dragonBlue = Color(red: 0.42, green: 0.84, blue: 0.98)
    static let dragonYellow = Color(red: 1.00, green: 0.85, blue: 0.27)
    static let dragonOutline = Color(red: 0.11, green: 0.14, blue: 0.25)

    // Flower
    static let flowerPetal = Color(red: 1.00, green: 0.81, blue: 0.22)
    static let flowerCenter = Color(red: 0.99, green: 0.63, blue: 0.22)
    static let flowerLeaf = Color(red: 0.23, green: 0.56, blue: 0.28)
    static let flowerOutline = dragonOutline

    // Book
    static let bookPage = Color(red: 1.00, green: 0.96, blue: 0.82)
    static let bookCorner = Color(red: 0.95, green: 0.61, blue: 0.23)
    static let bookOutline = dragonOutline

    // For dark outlines and accent borders
    static let accentOutline = dragonOutline
}
