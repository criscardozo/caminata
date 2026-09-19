import XCTest
@testable import Caminata

final class RouteSimplifierTests: XCTestCase {
    func testShortRoutesArePassedThrough() {
        let coordinates = [TestRoute.origin, TestRoute.offset(TestRoute.origin, northMetres: 10, eastMetres: 0)]
        XCTAssertEqual(RouteSimplifier.simplify(coordinates, tolerance: 5), coordinates)
    }

    func testCollinearPointsCollapseToTheEndpoints() {
        let coordinates = (0...10).map {
            TestRoute.offset(TestRoute.origin, northMetres: Double($0) * 10, eastMetres: 0)
        }
        let simplified = RouteSimplifier.simplify(coordinates, tolerance: 2)
        XCTAssertEqual(simplified, [coordinates[0], coordinates[10]])
    }

    func testCornersAreKept() {
        let simplified = RouteSimplifier.simplify(
            TestRoute.lShaped().map(\.coordinate),
            tolerance: 2
        )
        // Start, corner, end.
        XCTAssertEqual(simplified.count, 3)
    }

    func testEndpointsAreAlwaysPreserved() {
        let coordinates = TestRoute.lShaped().map(\.coordinate)
        let simplified = RouteSimplifier.simplify(coordinates, tolerance: 50)
        XCTAssertEqual(simplified.first, coordinates.first)
        XCTAssertEqual(simplified.last, coordinates[coordinates.count - 1])
    }

    func testOrderIsPreserved() {
        let coordinates = TestRoute.lShaped().map(\.coordinate)
        let simplified = RouteSimplifier.simplify(coordinates, tolerance: 1)
        let indices = simplified.compactMap { coordinates.firstIndex(of: $0) }
        XCTAssertEqual(indices, indices.sorted())
    }

    func testAZeroToleranceLeavesTheRouteAlone() {
        let coordinates = TestRoute.lShaped().map(\.coordinate)
        XCTAssertEqual(RouteSimplifier.simplify(coordinates, tolerance: 0), coordinates)
    }

    func testALargeRouteIsHandledWithoutRecursingPerPoint() {
        let coordinates = (0..<20_000).map {
            TestRoute.offset(
                TestRoute.origin,
                northMetres: Double($0) * 0.5,
                eastMetres: sin(Double($0) / 40) * 30
            )
        }
        let simplified = RouteSimplifier.simplify(coordinates, tolerance: 3)
        XCTAssertLessThan(simplified.count, coordinates.count / 10)
        XCTAssertGreaterThan(simplified.count, 2)
    }
}
