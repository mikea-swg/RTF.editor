//
//  ImageMetadataTextAttachment.swift
//  RTFEditor
//
//  Created by Josip Bernat on 28.05.2025..
//

import UIKit

class ImageMetadataTextAttachment: NSTextAttachment {
    
    var metadata: ImageMetadata?
    var onTap: ((_ metadata: ImageMetadata) -> Void)?
    
    private func calculateRotatedSize(_ size: CGSize, degrees: CGFloat) -> CGSize {
        
        let radians = degrees * .pi / 180
        let width = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
        let height = abs(size.width * sin(radians)) + abs(size.height * cos(radians))
        return CGSize(width: width, height: height)
    }
    
    override func attachmentBounds(for attributes: [NSAttributedString.Key : Any], location: any NSTextLocation, textContainer: NSTextContainer?, proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        let value = super.attachmentBounds(for: attributes, location: location, textContainer: textContainer, proposedLineFragment: proposedLineFragment, position: position)
        
        if let metadata {
            let rotatedSize = calculateRotatedSize(metadata.bounds.size, degrees: metadata.rotation)
            return CGRect(origin: .zero, size: rotatedSize)
        } else {
            return value
        }
    }
    
    override func viewProvider(for parentView: UIView?, location: NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        
        guard let metadata = self.metadata,
              let textLayoutManager = textContainer?.textLayoutManager else {
            return super.viewProvider(for: parentView, location: location, textContainer: textContainer)
        }
                
        // Create your custom view provider
        return ImageMetadataAttachmentViewProvider(attachment: self,
                                              parentView: parentView,
                                              textLayoutManager: textLayoutManager,
                                              location: location,
                                              metadata: metadata,
                                              onTap: onTap)
    }
}
