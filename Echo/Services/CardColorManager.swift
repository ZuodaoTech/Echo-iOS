import SwiftUI

/// Manages random color assignment for script cards
/// Colors are randomized on each app launch but remain consistent during the session
class CardColorManager {
    static let shared = CardColorManager()
    
    private var colorMap: [UUID: Color] = [:]
    
    private let colorPalette: [Color] = [
        Color.blue.opacity(0.6),
        Color.purple.opacity(0.6),
        Color.pink.opacity(0.6),
        Color.orange.opacity(0.6),
        Color.green.opacity(0.6),
        Color.teal.opacity(0.6),
        Color.indigo.opacity(0.6),
        Color.mint.opacity(0.6),
        Color.red.opacity(0.6),
        Color.cyan.opacity(0.6),
        Color.brown.opacity(0.6),
        Color.yellow.opacity(0.6)
    ]
    
    private init() {
        #if DEBUG
        print("🎨 CardColorManager initialized - colors will be randomized for this session")
        #endif
    }
    
    /// Get a color for a specific script ID
    /// Returns the same color for the same ID during the current session
    func getColor(for scriptId: UUID) -> Color {
        if let color = colorMap[scriptId] {
            return color
        }
        
        // Assign a random color that hasn't been used recently if possible
        let randomColor = selectRandomColor(avoiding: Array(colorMap.values.suffix(3)))
        colorMap[scriptId] = randomColor
        
        #if DEBUG
        print("🎨 Assigned color for script \(scriptId): \(String(describing: randomColor))")
        #endif
        return randomColor
    }
    
    /// Select a random color, trying to avoid recently used colors if possible
    private func selectRandomColor(avoiding recentColors: [Color]) -> Color {
        // Try to pick a color not in recent colors
        let availableColors = colorPalette.filter { color in
            !recentColors.contains(where: { $0.description == color.description })
        }
        
        // If we have available colors not recently used, pick from those
        if !availableColors.isEmpty {
            return availableColors.randomElement() ?? colorPalette[0]
        }
        
        // Otherwise pick any random color
        return colorPalette.randomElement() ?? colorPalette[0]
    }
    
    /// Refresh all colors (useful for manual shuffle)
    func refreshColors() {
        #if DEBUG
        print("🔄 Refreshing all card colors")
        #endif
        colorMap.removeAll()
    }
    
    /// Clear color for a specific script (when deleted)
    func removeColor(for scriptId: UUID) {
        colorMap.removeValue(forKey: scriptId)
    }
}