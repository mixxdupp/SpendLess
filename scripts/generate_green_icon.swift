import Cocoa
import CoreImage

// Paths
let inputPath = "docs/AppIcon.png" 
let outputPath = "Sources/SpendLess/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// 1. Load Image
guard let nsImage = NSImage(contentsOfFile: inputPath) else {
    print("Error: Could not load input image at \(inputPath)")
    exit(1)
}

guard let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let inputCIImage = CIImage(bitmapImageRep: bitmap) else {
    print("Error: Could not create CIImage")
    exit(1)
}

// 2. Apply Hue Adjust Filter (Red to Green)
let hueFilter = CIFilter(name: "CIHueAdjust")!
hueFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
// hueFilter.setValue(2.1, forKey: "inputAngle") // Previous value
// Let's stick to the green hue. 
// Note: If the user says "green border over it", it implies the background I added matches the hole, but the icon itself is small.
hueFilter.setValue(2.1, forKey: "inputAngle")

guard let greenCIImage = hueFilter.outputImage else {
    print("Error: Filter failed")
    exit(1)
}

// 3. Render to 1024x1024 Context with Scaling (Full Bleed)
let rep = NSCIImageRep(ciImage: greenCIImage)
let finalImage = NSImage(size: NSSize(width: 1024, height: 1024))

finalImage.lockFocus()

// A. Fill Background (Safety)
NSColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

// B. Draw Scaled Up to Remove Padding
// Scale factor 1.35 (Zoom in significantly to fill the square)
let scale: CGFloat = 1.35
let newWidth = 1024 * scale
let newHeight = 1024 * scale
let xOffset = (1024 - newWidth) / 2
let yOffset = (1024 - newHeight) / 2

rep.draw(in: NSRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight))

finalImage.unlockFocus()

// 4. Save to Disk
guard let tiffResult = finalImage.tiffRepresentation,
      let bitmapResult = NSBitmapImageRep(data: tiffResult),
      let pngData = bitmapResult.representation(using: .png, properties: [:]) else {
    print("Error: Could not generate PNG data")
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Success: App Icon updated (Zoomed Full Bleed) at \(outputPath)")
} catch {
    print("Error writing file: \(error)")
    exit(1)
}
