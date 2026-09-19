import XCTest
@testable import Caminata

final class GeoMathTests: XCTestCase {
    func testDistanceBetweenIdenticalCoordinatesIsZero() {
        let point = Coordinate(latitude: -34.6037, longitude: -58.3816)
        XCTAssertEqual(GeoMath.distance(from: point, to: point), 0, accuracy: 0.0001)
    }

    func testOneDegreeOfLatitudeIsAboutOneHundredAndElevenKilometres() {
        let distance = GeoMath.distance(
            from: Coordinate(latitude: 0, longitude: 0),
            to: Coordinate(latitude: 1, longitude: 0)
        )
        XCTAssertEqual(distance, 111_195, accuracy: 100)
    }

    func testDistanceMatchesAKnownLongRoute() {
        // Buenos Aires to Montevideo, roughly 205 km.
        let distance = GeoMath.distance(
            from: Coordinate(latitude: -34.6037, longitude: -58.3816),
            to: Coordinate(latitude: -34.9011, longitude: -56.1645)
        )
        XCTAssertEqual(distance / 1000, 205, accuracy: 3)
    }

    func testLocalProjectionPutsOriginAtZero() {
        let origin = Coordinate(latitude: -34.6037, longitude: -58.3816)
        let projected = GeoMath.localPlanarPoint(origin, origin: origin)
        XCTAssertEqual(projected.x, 0, accuracy: 0.0001)
        XCTAssertEqual(projected.y, 0, accuracy: 0.0001)
    }

    func testLocalProjectionMeasuresNorthwardOffsetInMetres() {
        let origin = TestRoute.origin
        let hundredMetresNorth = TestRoute.offset(origin, northMetres: 100, eastMetres: 0)
        let projected = GeoMath.localPlanarPoint(hundredMetresNorth, origin: origin)
        XCTAssertEqual(projected.y, 100, accuracy: 1)
        XCTAssertEqual(projected.x, 0, accuracy: 0.5)
    }
}
