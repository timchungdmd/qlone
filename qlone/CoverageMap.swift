import Foundation

/// Tracks which azimuth/elevation bins have been seen.
struct CoverageMap {
    let azBins: Int
    let elBins: Int
    
    private var visited: [[Bool]]   // [el][az]
    
    init(azBins: Int, elBins: Int) {
        self.azBins = max(1, azBins)
        self.elBins = max(1, elBins)
        self.visited = Array(
            repeating: Array(repeating: false, count: self.azBins),
            count: self.elBins
        )
    }
    
    mutating func mark(azimuthBin: Int, elevationBin: Int) {
        guard azimuthBin >= 0, azimuthBin < azBins,
              elevationBin >= 0, elevationBin < elBins else { return }
        visited[elevationBin][azimuthBin] = true
    }
    
    var azimuthProgress: Float {
        let total = azBins * elBins
        guard total > 0 else { return 0 }
        var count = 0
        for row in visited {
            for v in row where v { count += 1 }
        }
        return Float(count) / Float(total)
    }
    
    var elevationProgress: Float {
        // For now treat same as azimuth
        azimuthProgress
    }
    
    var isComplete: Bool {
        for row in visited {
            if row.contains(false) { return false }
        }
        return true
    }
}
