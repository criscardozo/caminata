import Foundation

/// Ramer-Douglas-Peucker, so that a long walk does not have to stroke tens of
/// thousands of segments when it is drawn onto a map image.
enum RouteSimplifier {
    static func simplify(_ coordinates: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard coordinates.count > 2, tolerance > 0 else { return coordinates }

        let origin = coordinates[0]
        let projected = coordinates.map { GeoMath.localPlanarPoint($0, origin: origin) }

        var keep = [Bool](repeating: false, count: coordinates.count)
        keep[0] = true
        keep[coordinates.count - 1] = true

        // Explicit stack rather than recursion: a pathological route would
        // otherwise recurse once per point.
        var stack: [(Int, Int)] = [(0, coordinates.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }

            var farthest = start
            var farthestDistance = 0.0
            for index in (start + 1)..<end {
                let distance = perpendicularDistance(
                    projected[index],
                    lineStart: projected[start],
                    lineEnd: projected[end]
                )
                if distance > farthestDistance {
                    farthestDistance = distance
                    farthest = index
                }
            }

            if farthestDistance > tolerance {
                keep[farthest] = true
                stack.append((start, farthest))
                stack.append((farthest, end))
            }
        }

        return zip(coordinates, keep).compactMap { $1 ? $0 : nil }
    }

    private static func perpendicularDistance(
        _ point: (x: Double, y: Double),
        lineStart: (x: Double, y: Double),
        lineEnd: (x: Double, y: Double)
    ) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = min(max(t, 0), 1)
        return hypot(point.x - (lineStart.x + t * dx), point.y - (lineStart.y + t * dy))
    }
}
