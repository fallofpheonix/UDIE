import SwiftUI

struct ThemeManager {
    let colors = ColorTokens.self
    let spacing = SpacingScale.self
    let elevation = ElevationTokens.self

    static let `default` = ThemeManager()
}
