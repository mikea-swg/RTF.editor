//
//  TextViewTapHandler.swift
//  RTFEditor
//
//  Created by Josip Bernat on 23.05.2025..
//

import Foundation
import UIKit

struct TextViewTapHandler {
    
    typealias OnPresentHandler = ((_ metadata: ImageMetadata) -> Void)
    
    @MainActor
    func handleTap(_ gesture: UITapGestureRecognizer,
                   textView: RichTextView,
                   onPresentHandler: @escaping OnPresentHandler) {
        
        let location = gesture.location(in: textView)
        
        guard let textLayoutManager = textView.textLayoutManager else {
            handleTapTextKit1(gesture, textView: textView, onPresentHandler: onPresentHandler)
            return
        }
        
        // Adjust for text container insets
        let adjustedLocation = CGPoint(
            x: location.x - textView.textContainerInset.left,
            y: location.y - textView.textContainerInset.top
        )
        
        // Enumerate all text in small segments to find which character was tapped
        textLayoutManager.enumerateTextSegments(
            in: textLayoutManager.documentRange,
            type: .standard,
            options: []
        ) { segmentRange, segmentFrame, baselinePosition, textContainer in
            
            // Check if tap is within this segment
            guard let segmentRange, segmentFrame.contains(adjustedLocation) else {
                return true // Continue enumeration
            }
            
            // Get character index for the start of this segment
            let characterIndex = textLayoutManager.offset(from: textLayoutManager.documentRange.location,
                                                          to: segmentRange.location )
            
            // Check if there's an attachment at this position
            guard characterIndex < textView.attributedText.length else {
                return true // Continue enumeration
            }
            
            let attrs = textView.attributedText.attributes(at: characterIndex, effectiveRange: nil)
            
            guard let attachment = attrs[.attachment] as? NSTextAttachment,
                  let fileWrapper = attachment.fileWrapper,
                  let imageData = fileWrapper.regularFileContents,
                  let _ = UIImage(data: imageData),
                  let name = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(name),
                  let metadata = textView.imageMetadataDict[uuid] else {
                return true // Continue enumeration
            }
            
//            let containerOrigin = textView.textContainerInset
//            let sourceRect = segmentFrame.offsetBy(
//                dx: containerOrigin.left,
//                dy: containerOrigin.top
//            )
            
            // Present your SwiftUI resize sheet or popover
            DispatchQueue.main.async {
                onPresentHandler(metadata)
            }
            return false // Stop enumeration
        }
    }
    
    // Fallback method for TextKit1 (your original code)
    @MainActor
    private func handleTapTextKit1(_ gesture: UITapGestureRecognizer,
                                   textView: RichTextView,
                                   onPresentHandler: OnPresentHandler) {
        
        let location = gesture.location(in: textView)
        
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // Check if there's an attachment at this character index
        let attrs = textView.attributedText.attributes(at: characterIndex, effectiveRange: nil)
        
        
        guard let attachment = attrs[.attachment] as? NSTextAttachment,
              let fileWrapper = attachment.fileWrapper,
              let imageData = fileWrapper.regularFileContents,
              let _ = UIImage(data: imageData),
              let name = fileWrapper.filename,
              let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(name),
              let metadata = textView.imageMetadataDict[uuid] else {
            return  // Continue enumeration
        }
        
        // Optional: Convert to screen rect for popover
//        let glyphRange = NSRange(location: characterIndex, length: 1)
//        let attachmentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
//        let containerOrigin = textView.textContainerInset
//        let sourceRect = attachmentRect.offsetBy(dx: containerOrigin.left, dy: containerOrigin.top)
        
        // Present your SwiftUI resize sheet or popover
        onPresentHandler(metadata)
    }
}
