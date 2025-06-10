//
//  ImageResizeFactory.swift
//  RTFEditor
//
//  Created by Josip Bernat on 27.05.2025..
//

import Foundation
import UIKit

struct ImageResizeFactory {
    /*
    static func generateImage(originalImage: UIImage, metadata: ImageMetadata) -> UIImage {
        
        let imageSize = CGSize(width: metadata.width, height: metadata.height)
        let radians = metadata.rotation * .pi / 180

        // Final content size after border is added
        let borderedSize = CGSize(
            width: imageSize.width + metadata.borderWidth,
            height: imageSize.height + metadata.borderWidth
        )

        // Calculate the exact size needed to contain the rotated image at any angle
        let rotatedSize = calculateRotatedSize(borderedSize, radians: radians)

        // Shadow padding (could be 0)
        let shadowPadding: CGFloat = metadata.shadowRadius + max(abs(metadata.shadowOffsetX), abs(metadata.shadowOffsetY))

        let canvasSize = CGSize(
            width: rotatedSize.width + shadowPadding * 2,
            height: rotatedSize.height + shadowPadding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = originalImage.scale

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let resultImage = renderer.image { context in
            let cgContext = context.cgContext

            // Move origin to center of canvas
            cgContext.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)

            // Apply shadow if needed
            if metadata.shadowRadius > 0 {
                cgContext.setShadow(
                    offset: CGSize(width: metadata.shadowOffsetX, height: metadata.shadowOffsetY),
                    blur: metadata.shadowRadius,
                    color: UIColor(metadata.shadowColor).cgColor
                )
            }

            // Apply rotation
            cgContext.rotate(by: radians)

            // Apply additional flipping if needed
            let scaleX: CGFloat = metadata.isFlippedHorizontal ? -1 : 1
            let scaleY: CGFloat = metadata.isFlippedVertical ? -1 : 1
            cgContext.scaleBy(x: scaleX, y: scaleY)

            // Draw border if needed
            if metadata.borderWidth > 0 {
                let borderRect = CGRect(
                    x: -borderedSize.width / 2,
                    y: -borderedSize.height / 2,
                    width: borderedSize.width,
                    height: borderedSize.height
                )

                cgContext.setStrokeColor(UIColor(metadata.borderColor).cgColor)
                cgContext.setLineWidth(metadata.borderWidth)
                cgContext.stroke(borderRect)
            }

            // Draw image with opacity - use original image size for drawing
            let drawRect = CGRect(
                x: -imageSize.width / 2,
                y: -imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )

            cgContext.setAlpha(metadata.opacity)
            originalImage.draw(in: drawRect)
        }
            
        return resultImage
    }
    
    private static func calculateRotatedSize(_ size: CGSize, radians: CGFloat) -> CGSize {
        let width = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
        let height = abs(size.width * sin(radians)) + abs(size.height * cos(radians))
        return CGSize(width: width, height: height)
    }
*/
     }
