//
//  StyledImageAttachmentViewProvider.swift
//  RTFEditor
//
//  Created by Josip Bernat on 28.05.2025..
//

import UIKit
import SwiftUI

class MetadataAttachmentViewProvider: NSTextAttachmentViewProvider, @unchecked Sendable {
        
    let metadata: ImageMetadata
    let onTap: ((_ metadata: ImageMetadata) -> Void)?
    
    init(attachment: NSTextAttachment,
         parentView: UIView?,
         textLayoutManager: NSTextLayoutManager,
         location: any NSTextLocation,
         metadata: ImageMetadata,
         onTap: ((_ metadata: ImageMetadata) -> Void)?) {
        
        self.metadata = metadata
        self.onTap = onTap
        
        super.init(textAttachment: attachment,
                   parentView: parentView,
                   textLayoutManager: textLayoutManager,
                   location: location)
    }
    
    override func loadView() {
        
        MainActor.assumeIsolated {
            guard let attachment = self.textAttachment,
                  let fileWrapper = attachment.fileWrapper,
                  let imageData = fileWrapper.regularFileContents,
                  let image = UIImage(data: imageData),
                  let name = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(name),
                  uuid == metadata.id else {
                
                self.view = UIView()
                return
            }

            let containerView = MetadataAttachmentContainerView(image: image, metadata: metadata, onTap: onTap)
            self.view = containerView
        }
    }
}
