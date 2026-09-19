import UIKit
import XCTest
@testable import Caminata

final class RouteOverlayDrawerTests: XCTestCase {
    private let size = CGSize(width: 400, height: 400)
    private lazy var base = UIImage.solid(.gray, size: size)

    private func isGrey(_ pixel: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)?) -> Bool {
        guard let pixel else { return false }
        return pixel.red == pixel.green && pixel.green == pixel.blue
    }

    func testTheOutputKeepsTheBaseImageSize() {
        let image = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 50, y: 50), CGPoint(x: 350, y: 350)]
        )
        XCTAssertEqual(image.size, size)
    }

    func testTheRouteIsActuallyDrawnOntoTheMap() throws {
        let image = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 40, y: 200), CGPoint(x: 360, y: 200)]
        )

        // A point on the line is no longer the flat grey of the base image.
        let onRoute = try XCTUnwrap(image.pixel(x: 200, y: 200))
        XCTAssertFalse(
            isGrey(onRoute),
            "Expected the route colour on the line, got \(onRoute)"
        )
    }

    func testAreasAwayFromTheRouteAreLeftAlone() throws {
        let image = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 40, y: 200), CGPoint(x: 360, y: 200)]
        )

        let offRoute = try XCTUnwrap(image.pixel(x: 200, y: 60))
        XCTAssertTrue(isGrey(offRoute), "Expected untouched grey away from the route, got \(offRoute)")
    }

    func testTheRouteIsOutlinedSoItReadsOverAnyTerrain() throws {
        let image = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 40, y: 200), CGPoint(x: 360, y: 200)]
        )

        let centre = try XCTUnwrap(image.pixel(x: 200, y: 200))
        let halo = try XCTUnwrap(image.pixel(x: 200, y: 203))
        XCTAssertNotEqual(
            [centre.red, centre.green, centre.blue],
            [halo.red, halo.green, halo.blue],
            "Expected the halo to differ from the route colour"
        )
    }

    func testStartAndEndAreMarkedDifferently() throws {
        let image = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 80, y: 200), CGPoint(x: 320, y: 200)]
        )

        let start = try XCTUnwrap(image.pixel(x: 80, y: 200))
        let end = try XCTUnwrap(image.pixel(x: 320, y: 200))
        XCTAssertNotEqual([start.red, start.green, start.blue], [end.red, end.green, end.blue])
    }

    func testASingleFixStillGetsAStartMarker() throws {
        let image = RouteOverlayDrawer.image(base: base, route: [CGPoint(x: 200, y: 200)])
        XCTAssertFalse(isGrey(try XCTUnwrap(image.pixel(x: 200, y: 200))))
    }

    func testAnEmptyRouteLeavesTheMapUntouched() throws {
        let image = RouteOverlayDrawer.image(base: base, route: [])
        XCTAssertTrue(isGrey(try XCTUnwrap(image.pixel(x: 200, y: 200))))
    }

    func testTheCaptionIsDrawnAlongTheBottom() throws {
        let plain = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 40, y: 40), CGPoint(x: 360, y: 60)]
        )
        let captioned = RouteOverlayDrawer.image(
            base: base,
            route: [CGPoint(x: 40, y: 40), CGPoint(x: 360, y: 60)],
            caption: "3.20 km  ·  38:10"
        )

        let bottomPlain = try XCTUnwrap(plain.pixel(x: 200, y: 370))
        let bottomCaptioned = try XCTUnwrap(captioned.pixel(x: 200, y: 370))
        XCTAssertNotEqual(
            [bottomPlain.red, bottomPlain.green, bottomPlain.blue],
            [bottomCaptioned.red, bottomCaptioned.green, bottomCaptioned.blue]
        )
    }

    func testTheCompositedOverlayIsAvailableAsACIArtifact() throws {
        let route = stride(from: 40.0, through: 360.0, by: 8.0).map { x in
            CGPoint(x: x, y: 200 + sin(x / 30) * 90)
        }
        let image = RouteOverlayDrawer.image(
            base: base,
            route: route,
            caption: "Overlay drawing test  ·  no map tiles needed"
        )
        CIOutput.write(try XCTUnwrap(image.pngData()), named: "overlay-drawing.png")
    }
}
