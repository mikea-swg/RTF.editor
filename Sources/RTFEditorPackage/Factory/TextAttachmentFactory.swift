//
//  TextAttachmentFactory.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation
import UIKit

struct TextAttachmentFactory {
    
    static func createFileWrapperName(metadata: ImageMetadata) -> String {
        createFileWrapperName(id: metadata.id)
    }
    
    static func createFileWrapperName(id: UUID) -> String {
        "image_\(id).png"
    }

    static func metadataIdFromFileWrapperName(_ fileWrapperName: String) -> UUID? {
        let name = fileWrapperName
            .components(separatedBy: "_")
            .last?
            .components(separatedBy: ".")
            .first
        
        guard let name else { return nil }
        let result = UUID(uuidString: name)
        return result
    }
    
    @MainActor
    static func createAttributedStringFromImage(_ image: UIImage,
                                                textView: UITextView,
                                                onTap: ((_ metadata: ImageMetadata) -> Void)?,
                                                existingMetadata: ImageMetadata?) -> (string: NSAttributedString, medatadata: ImageMetadata) {
                
        let scaledImage = existingMetadata != nil ? image : self.resizeImage(image)
        
        var defaultSize = scaledImage.size
        
        if scaledImage.size.width > textView.frame.width * 0.8 {
            defaultSize = CGSize(width: textView.frame.width * 0.8,
                                 height: textView.frame.width * 0.8 / (defaultSize.width / defaultSize.height))
        }
        
        let metadata = existingMetadata ?? ImageMetadata(image: scaledImage, defaultSize: defaultSize)
        
        // Create text attachment
        let attachment = ImageMetadataTextAttachment()
        attachment.metadata = metadata
        attachment.onTap = onTap
        
        // Create attributed string with the image
        let imageAttrString = NSMutableAttributedString(attachment: attachment)
        
        if let imageData = scaledImage.pngData() {
            let fileWrapper = FileWrapper(regularFileWithContents: imageData)
            fileWrapper.preferredFilename = createFileWrapperName(metadata: metadata)
            fileWrapper.filename = fileWrapper.preferredFilename
            attachment.fileWrapper = fileWrapper
        }
        
        // Apply default text attributes based on current text position
        let insertLocation = textView.selectedRange.location
        
        // Safely extract current paragraph style at insertion point
        var existingStyle = NSMutableParagraphStyle()
        if let attributedText = textView.attributedText, attributedText.length > 0 {
            let safeIndex = max(0, min(insertLocation - 1, attributedText.length - 1))
            let currentAttributes = attributedText.attributes(at: safeIndex, effectiveRange: nil)
            if let style = (currentAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
                existingStyle = style
            }
        } else {
            // Use typingAttributes when attributedText is empty
            let typingAttributes = textView.typingAttributes
            if let style = (typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
                existingStyle = style
            }
        }
        
        // Build attributes dictionary
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: existingStyle,
            .font: textView.font ?? UIFont.systemFont(ofSize: 17),
            .foregroundColor: textView.textColor ?? .label
        ]
        
        // Apply attributes to the inserted string
        imageAttrString.addAttributes(attributes, range: NSRange(location: 0, length: imageAttrString.length))
        
        return (imageAttrString, metadata)
    }
    
    @MainActor
    private static func resizeImage(_ image: UIImage) -> UIImage {
        
        let maxDimension: CGFloat = 750.0
        let originalSize = image.size
        let width = originalSize.width
        let height = originalSize.height

        // No need to resize if both dimensions are already under the limit
        guard max(width, height) > maxDimension else {
            return image
        }

        // Scale so that the largest side is 750px
        let scaleFactor = maxDimension / max(width, height)
        let newSize = CGSize(width: width * scaleFactor, height: height * scaleFactor)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? image
    }
}
