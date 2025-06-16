//
//  RichTextView+Drop.swift
//  RTFEditor
//
//  Created by Josip Bernat on 04.06.2025..
//

import Foundation
import UniformTypeIdentifiers
import UIKit

extension UIDropSession {
    
    fileprivate var hasDroppableContent: Bool {
        hasImage || hasText
    }
    
    fileprivate var hasImage: Bool {
        canLoadObjects(ofClass: UIImage.self)
    }
    
    fileprivate var hasText: Bool {
        canLoadObjects(ofClass: String.self)
    }
}

extension RichTextView: UIDropInteractionDelegate {
    
    var supportedDropInteractionTypes: [UTType] {
        [.image, .text, .plainText, .utf8PlainText, .utf16PlainText]
    }
    
    /// Whether or not the view can handle a drop session.
    open func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        guard session.hasImage else { return false }
        let identifiers = supportedDropInteractionTypes.map { $0.identifier }
        return session.hasItemsConforming(toTypeIdentifiers: identifiers)
    }
    
    /// Handle an updated drop session.
    open func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        
        let operation = dropInteractionOperation(for: session)
        let proposal = UIDropProposal(operation: operation)
        
        switch operation {
        case .cancel, .forbidden:
            return proposal
        case .copy, .move:
            break
        @unknown default:
            fatalError()
        }
        
        becomeFirstResponder()
        let point = session.location(in: self)
        if let position = closestPosition(to: point) {
            selectedTextRange = textRange(from: position, to: position)
        }
        
        proposal.isPrecise = true
        return proposal
    }
    
    open func dropInteraction(_ interaction: UIDropInteraction, performDrop session: any UIDropSession) {
        
        guard session.canLoadObjects(ofClass: UIImage.self) else { return }
        
        session.loadObjects(ofClass: UIImage.self) { [weak self] items in
            guard let self else { return }
            guard let images = items as? [UIImage], let originalImage = images.first else { return }
            
            self.interactor?.insertImage(originalImage)
        }
    }

    /// The drop interaction operation for a certain session.
    public func dropInteractionOperation(for session: UIDropSession) -> UIDropOperation {
        guard session.hasDroppableContent else { return .forbidden }
        
        let location = session.location(in: self)
        return bounds.contains(location) ? .copy : .cancel
    }
}
