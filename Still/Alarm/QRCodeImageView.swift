import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct QRCodeImageView: View {
    let content: String
    var dimension: CGFloat = 200

    var body: some View {
        Group {
            if let image = Self.qrUIImage(content: content, dimension: dimension) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: dimension, height: dimension)
            }
        }
    }

    /// Bitmap for sharing, printing, or saving (higher `dimension` = sharper print).
    static func qrUIImage(content: String, dimension: CGFloat) -> UIImage? {
        makeImage(from: content, dimension: dimension)
    }

    private static func makeImage(from string: String, dimension: CGFloat) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
