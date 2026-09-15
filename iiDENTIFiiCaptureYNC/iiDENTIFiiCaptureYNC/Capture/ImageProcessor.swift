//
//  ImageProcessor.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import UIKit

// NOTES:
// This ImageProcessor file is to downscales the image before going to Core Data.
// Due to the nature of images been inherently large files it was best to not store such large files in memory.
nonisolated enum ImageProcessor {
    static let maxDimension: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.7

    static func process(_ image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let resized = resize(image, maxDimension: maxDimension)
            return resized.jpegData(compressionQuality: jpegQuality)
        }.value
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
