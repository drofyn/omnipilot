import AppKit

// 用法: swift Scripts/RenderIcon.swift <svg> [<尺寸> <输出.png>]...
//
// 用 NSImage 直接光栅化 SVG（保留透明通道），按给定像素尺寸输出 PNG。
// qlmanage 会给 SVG 铺不透明白底，因此不能用来做模板图。

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, (arguments.count - 1) % 2 == 0 else {
    FileHandle.standardError.write(Data("usage: RenderIcon.swift <svg> [<size> <out.png>]...\n".utf8))
    exit(2)
}

let svgPath = arguments[0]
guard let source = NSImage(contentsOfFile: svgPath) else {
    FileHandle.standardError.write(Data("error: 无法加载 SVG: \(svgPath)\n".utf8))
    exit(1)
}

var index = 1
while index + 1 < arguments.count {
    guard let size = Int(arguments[index]) else {
        FileHandle.standardError.write(Data("error: 无效尺寸 \(arguments[index])\n".utf8))
        exit(1)
    }
    let outputPath = arguments[index + 1]
    index += 2

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write(Data("error: 无法创建位图 \(size)px\n".utf8))
        exit(1)
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 透明底
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    // 等比缩放居中
    let sourceSize = source.size
    let scale = min(CGFloat(size) / sourceSize.width, CGFloat(size) / sourceSize.height)
    let drawWidth = sourceSize.width * scale
    let drawHeight = sourceSize.height * scale
    source.draw(
        in: NSRect(
            x: (CGFloat(size) - drawWidth) / 2,
            y: (CGFloat(size) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        ),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("error: 无法编码 PNG\n".utf8))
        exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
    } catch {
        FileHandle.standardError.write(Data("error: 写入失败 \(outputPath): \(error)\n".utf8))
        exit(1)
    }
}
