import UIKit
import XCTest
@testable import Caminata

/// These exercise the whole export path against real Apple map tiles, so they
/// need the network. When tiles cannot be fetched the test skips rather than
/// failing: the drawing itself is covered by RouteOverlayDrawerTests.
@MainActor
final class MapSnapshotRendererTests: XCTestCase {
    func testRendersARouteOntoRealMapTiles() async throws {
        let walk = TestRoute.walk()
        let renderer = MapSnapshotRenderer(size: CGSize(width: 800, height: 800))

        let image: UIImage
        do {
            image = try await renderer.render(
                walk: walk,
                caption: WalkFormatting.summaryCaption(for: walk)
            )
        } catch {
            throw XCTSkip("Map tiles unavailable: \(error)")
        }

        XCTAssertEqual(image.size, CGSize(width: 800, height: 800))

        let png = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(png.count, 10_000, "The rendered map looks empty")
        CIOutput.write(png, named: "walk-map.png")
    }

    func testRenderingAWalkWithNoFixesFails() async {
        let walk = Walk(
            metadata: WalkMetadata(id: UUID(), startedAt: TestRoute.start, endedAt: TestRoute.start),
            points: []
        )

        do {
            _ = try await MapSnapshotRenderer().render(walk: walk, caption: nil)
            XCTFail("Expected rendering to fail without coordinates")
        } catch MapSnapshotRenderer.RenderError.noCoordinates {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportProducesBothAttachments() async throws {
        let walk = TestRoute.walk()
        let export: WalkExport
        do {
            export = try await WalkExporter().export(walk)
        } catch {
            throw XCTSkip("Map tiles unavailable: \(error)")
        }

        XCTAssertEqual(export.attachments.count, 2)
        XCTAssertEqual(export.imageURL.pathExtension, "png")
        XCTAssertEqual(export.gpxURL.pathExtension, "gpx")

        for url in export.attachments {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Missing attachment at \(url.lastPathComponent)"
            )
        }

        let gpx = try String(contentsOf: export.gpxURL, encoding: .utf8)
        XCTAssertTrue(gpx.contains("<trkpt "))

        CIOutput.write(try Data(contentsOf: export.imageURL), named: "exported-\(export.imageURL.lastPathComponent)")
        CIOutput.write(Data(gpx.utf8), named: "exported-\(export.gpxURL.lastPathComponent)")
    }

    func testTheEmailBodyCarriesTheHeadlineNumbers() {
        let walk = TestRoute.walk()
        let body = WalkExporter().emailBody(for: walk)

        XCTAssertTrue(body.contains("Distance:"))
        XCTAssertTrue(body.contains("Duration:"))
        XCTAssertTrue(body.contains(WalkFormatting.distance(walk.stats.distance)))
    }
}
