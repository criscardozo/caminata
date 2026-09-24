import UIKit

struct RouteOverlayStyle {
    var routeColor: UIColor = RouteColor.uiColor(from: RouteColor.default)
    /// A light outline under the line keeps it readable over parks, water and
    /// dense street grids alike.
    var haloColor: UIColor = UIColor.white.withAlphaComponent(0.95)
    var startColor: UIColor = UIColor(red: 0.13, green: 0.65, blue: 0.35, alpha: 1)
    var endColor: UIColor = UIColor(red: 0.12, green: 0.20, blue: 0.28, alpha: 1)
    var captionBackground: UIColor = UIColor.black.withAlphaComponent(0.62)
    var captionColor: UIColor = .white

    /// Everything scales off the image width so the same style works for a
    /// thumbnail and for a full-resolution export.
    func routeWidth(for width: CGFloat) -> CGFloat { max(3, width * 0.009) }
    func haloWidth(for width: CGFloat) -> CGFloat { routeWidth(for: width) * 1.9 }
    func markerRadius(for width: CGFloat) -> CGFloat { max(5, width * 0.014) }
    func captionFontSize(for width: CGFloat) -> CGFloat { max(11, width * 0.026) }
}

/// Composites a route onto an already-rendered map image.
///
/// It knows nothing about MapKit: it takes points in image space, which is what
/// makes it testable without a network round trip for map tiles.
enum RouteOverlayDrawer {
    static func image(
        base: UIImage,
        route: [CGPoint],
        caption: String? = nil,
        style: RouteOverlayStyle = RouteOverlayStyle()
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        return renderer.image { context in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            draw(route: route, in: context.cgContext, width: base.size.width, style: style)
            drawMarkers(route: route, in: context.cgContext, width: base.size.width, style: style)
            if let caption {
                drawCaption(caption, in: base.size, style: style)
            }
        }
    }

    private static func draw(
        route: [CGPoint],
        in context: CGContext,
        width: CGFloat,
        style: RouteOverlayStyle
    ) {
        guard route.count > 1 else { return }

        let path = CGMutablePath()
        path.addLines(between: route)

        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.addPath(path)
        context.setStrokeColor(style.haloColor.cgColor)
        context.setLineWidth(style.haloWidth(for: width))
        context.strokePath()

        context.addPath(path)
        context.setStrokeColor(style.routeColor.cgColor)
        context.setLineWidth(style.routeWidth(for: width))
        context.strokePath()
    }

    private static func drawMarkers(
        route: [CGPoint],
        in context: CGContext,
        width: CGFloat,
        style: RouteOverlayStyle
    ) {
        guard let start = route.first else { return }
        marker(at: start, colour: style.startColor, in: context, width: width, style: style)

        if let end = route.last, route.count > 1 {
            marker(at: end, colour: style.endColor, in: context, width: width, style: style)
        }
    }

    private static func marker(
        at point: CGPoint,
        colour: UIColor,
        in context: CGContext,
        width: CGFloat,
        style: RouteOverlayStyle
    ) {
        let radius = style.markerRadius(for: width)
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect)
        context.setFillColor(colour.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: radius * 0.28, dy: radius * 0.28))
    }

    private static func drawCaption(
        _ caption: String,
        in size: CGSize,
        style: RouteOverlayStyle
    ) {
        let fontSize = style.captionFontSize(for: size.width)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: style.captionColor
        ]
        let text = caption as NSString
        let inset = size.width * 0.03
        let available = CGSize(width: size.width - inset * 4, height: size.height)
        let textSize = text.boundingRect(
            with: available,
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        ).size

        let barHeight = textSize.height + inset * 1.4
        let bar = CGRect(
            x: inset,
            y: size.height - barHeight - inset,
            width: size.width - inset * 2,
            height: barHeight
        )

        let background = UIBezierPath(roundedRect: bar, cornerRadius: barHeight * 0.28)
        style.captionBackground.setFill()
        background.fill()

        text.draw(
            with: bar.insetBy(dx: inset, dy: inset * 0.7),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
    }
}
