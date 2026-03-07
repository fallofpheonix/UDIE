import SwiftUI
import UIKit

enum ColorTokens {
    static let mapFadeTop = Color(light: "FFFFFF", dark: "0F1418").opacity(0.08)
    static let mapFadeBottom = Color(light: "D8E0E5", dark: "12181D").opacity(0.42)
    static let mapOverlaySoft = Color(light: "EDF2F5", dark: "141B20").opacity(0.52)

    static let appBackground = Color(light: "F4F7F8", dark: "1C2328")
    static let surfacePrimary = Color(light: "FFFFFF", dark: "222A30")
    static let surfaceSecondary = Color(light: "EEF3F5", dark: "28323A")
    static let cardSurface = surfacePrimary
    static let cardStroke = Color(light: "D8E0E5", dark: "3A4650")
    static let surfaceTintedA = Color(light: "EAF3F1", dark: "263833")
    static let surfaceTintedB = Color(light: "F2EEF8", dark: "352E3D")
    static let surfaceTintedC = Color(light: "F8F1E8", dark: "3B3428")

    static let lowRisk = Color(hex: "34C759")
    static let mediumRisk = Color(hex: "FF9F0A")
    static let highRisk = Color(hex: "FF3B30")

    static let neutralPrimary = Color(hex: "2F4858")
    static let neutralAccent = Color(hex: "6FA3A9")
    static let textPrimary = Color(light: "17222A", dark: "E7EEF3")
    static let textSecondary = Color(light: "4E626E", dark: "9FB0BA")
    static let controlFill = Color(light: "F0F4F6", dark: "2C373F")
    static let chipBackground = Color(light: "E7EFF2", dark: "2B3740")
    static let accent = Color.accent
    
    // Adaptive Aliases
    static var adaptiveSurface: Color { Color.adaptiveSurface }
    static var adaptiveBackground: Color { Color.adaptiveBackground }
}
