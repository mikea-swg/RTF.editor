//
//  TextInteraction.swift
//  RTFEditorPackage
//
//  Created by Josip Bernat on 23.06.2025..
//

import Foundation
import UIKit

public struct TextInteraction {
    
    static func replaceTextAttachments(in attributedString: NSAttributedString,
                                       imagesMetadataDict: [UUID: ImageMetadata]) -> (text: NSAttributedString,                                    
                                                                                      attachments: [ImageMetadataTextAttachment]) {
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var attachments = [ImageMetadataTextAttachment]()
        
        let range = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let originalAttachment = value as? NSTextAttachment,
                  let fileWrapper = originalAttachment.fileWrapper,
                  let filename = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(filename),
                  let metadata = imagesMetadataDict[uuid] else {
                return
            }
            
            guard originalAttachment is ImageMetadataTextAttachment == false else { return }
            
            // Create new styled attachment
            let styledAttachment = ImageMetadataTextAttachment()
            styledAttachment.fileWrapper = fileWrapper
            styledAttachment.metadata = metadata
            attachments.append(styledAttachment)
            
            // Replace the attachment
            mutableString.addAttribute(.attachment, value: styledAttachment, range: attachmentRange)
        }
        
        return (mutableString, attachments)
    }
}
