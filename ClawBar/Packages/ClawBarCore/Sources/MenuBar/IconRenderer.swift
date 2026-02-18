import AppKit

public enum IconRenderer {
    private static let size = NSSize(width: 18, height: 18)
    private static let scale: CGFloat = 2
    private static let canvasSize = NSSize(
        width: size.width * scale,
        height: size.height * scale
    )

    // Cache — MainActor-isolated for thread safety
    @MainActor private static var cache: [IconBucket: NSImage] = [:]

    @MainActor
    public static func render(bucket: IconBucket) -> NSImage {
        if let cached = cache[bucket] { return cached }

        let image = renderIcon(bucket: bucket)
        image.isTemplate = true

        // Limit cache size
        if cache.count > 64 {
            cache.removeAll()
        }
        cache[bucket] = image

        return image
    }

    public static func renderLoading() -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let scale: CGFloat = 2
            NSGraphicsContext.current?.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
            let scaledRect = CGRect(
                x: rect.origin.x * scale,
                y: rect.origin.y * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            drawBars(in: scaledRect, topFill: 0.3, bottomFill: 0.3, topDimmed: true, bottomDimmed: true)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func renderIcon(bucket: IconBucket) -> NSImage {
        let topFill = bucket.openClawConnected ? Double(max(0, bucket.openClaw)) * 5 / 100 : 0
        let bottomFill = bucket.claudeAvailable ? Double(max(0, bucket.claude)) * 5 / 100 : 0
        let topDimmed = !bucket.openClawConnected
        let bottomDimmed = !bucket.claudeAvailable

        let image = NSImage(size: size, flipped: false) { rect in
            let scale: CGFloat = 2
            NSGraphicsContext.current?.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
            let scaledRect = CGRect(
                x: rect.origin.x * scale,
                y: rect.origin.y * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            drawBars(in: scaledRect, topFill: topFill, bottomFill: bottomFill, topDimmed: topDimmed, bottomDimmed: bottomDimmed)
            return true
        }
        return image
    }

    private static func drawBars(
        in rect: CGRect,
        topFill: Double,
        bottomFill: Double,
        topDimmed: Bool,
        bottomDimmed: Bool
    ) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barWidth = rect.width - 8  // 4px padding each side
        let barHeight: CGFloat = 10
        let gap: CGFloat = 6
        let totalHeight = barHeight * 2 + gap
        let startY = (rect.height - totalHeight) / 2
        let startX = (rect.width - barWidth) / 2
        let cornerRadius: CGFloat = 3

        // Bottom bar (Claude) — drawn first because coordinate system is bottom-up
        let bottomRect = CGRect(x: startX, y: startY, width: barWidth, height: barHeight)
        drawBar(ctx: ctx, rect: bottomRect, fill: bottomFill, dimmed: bottomDimmed, cornerRadius: cornerRadius)

        // Top bar (OpenClaw)
        let topRect = CGRect(x: startX, y: startY + barHeight + gap, width: barWidth, height: barHeight)
        drawBar(ctx: ctx, rect: topRect, fill: topFill, dimmed: topDimmed, cornerRadius: cornerRadius)
    }

    private static func drawBar(
        ctx: CGContext,
        rect: CGRect,
        fill: Double,
        dimmed: Bool,
        cornerRadius: CGFloat
    ) {
        let alpha: CGFloat = dimmed ? 0.3 : 1.0

        // Track
        let trackPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.25 * alpha).cgColor)
        ctx.addPath(trackPath)
        ctx.fillPath()

        // Fill
        if fill > 0 {
            let fillWidth = rect.width * CGFloat(min(1, max(0, fill)))
            let fillRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: fillWidth, height: rect.height)
            let fillPath = CGPath(roundedRect: fillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.85 * alpha).cgColor)
            ctx.addPath(fillPath)
            ctx.fillPath()
        }
    }
}
