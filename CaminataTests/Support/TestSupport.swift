import Foundation
import UIKit
@testable import Caminata

enum TestRoute {
    static let origin = Coordinate(latitude: -34.603722, longitude: -58.381592)
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func offset(_ base: Coordinate, northMetres: Double, eastMetres: Double) -> Coordinate {
        let metresPerDegreeLatitude = 111_320.0
        let metresPerDegreeLongitude = metresPerDegreeLatitude * cos(base.latitude * .pi / 180)
        return Coordinate(
            latitude: base.latitude + northMetres / metresPerDegreeLatitude,
            longitude: base.longitude + eastMetres / metresPerDegreeLongitude
        )
    }

    /// A 600 m walk that turns a corner, at a plausible walking pace.
    static func lShaped(
        legs: Int = 30,
        stepMetres: Double = 10,
        stepSeconds: TimeInterval = 8
    ) -> [TrackPoint] {
        var points: [TrackPoint] = []
        var index = 0

        for step in 0...legs {
            points.append(TrackPoint(
                coordinate: offset(origin, northMetres: Double(step) * stepMetres, eastMetres: 0),
                altitude: 25,
                horizontalAccuracy: 5,
                speed: stepMetres / stepSeconds,
                timestamp: start.addingTimeInterval(Double(index) * stepSeconds)
            ))
            index += 1
        }

        for step in 1...legs {
            points.append(TrackPoint(
                coordinate: offset(
                    origin,
                    northMetres: Double(legs) * stepMetres,
                    eastMetres: Double(step) * stepMetres
                ),
                altitude: 25,
                horizontalAccuracy: 5,
                speed: stepMetres / stepSeconds,
                timestamp: start.addingTimeInterval(Double(index) * stepSeconds)
            ))
            index += 1
        }

        return points
    }

    static func walk(points: [TrackPoint]? = nil) -> Walk {
        let recorded = points ?? lShaped()
        return Walk(
            metadata: WalkMetadata(
                id: UUID(),
                startedAt: recorded[0].timestamp,
                endedAt: recorded[recorded.count - 1].timestamp
            ),
            points: recorded
        )
    }
}

/// Writes files where the CI job can pick them up as workflow artifacts.
///
/// Failures are logged rather than swallowed: a silently missing artifact looks
/// exactly like a test that never ran.
enum CIOutput {
    @discardableResult
    static func write(_ data: Data, named name: String) -> URL? {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            print("CIOutput: no documents directory available")
            return nil
        }

        let directory = documents.appendingPathComponent("CIOutput", isDirectory: true)
        let destination = directory.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            print("CIOutput: wrote \(data.count) bytes to \(destination.path)")
            return destination
        } catch {
            print("CIOutput: failed to write \(name): \(error)")
            return nil
        }
    }
}

extension UIImage {
    /// Samples a single pixel in image coordinates, with the origin top-left.
    func pixel(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard let cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard x >= 0, y >= 0, x < width, y < height else { return nil }

        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(
            cgImage,
            in: CGRect(
                x: CGFloat(-x),
                y: CGFloat(-(height - 1 - y)),
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    static func solid(_ colour: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
