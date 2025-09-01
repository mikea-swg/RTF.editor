//
//  RichTextView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation
import UIKit
import UniformTypeIdentifiers

public class RichTextView: UITextView, UITextPasteDelegate {
    
    public let interactor: RichTextViewInteractor
    
    internal var imageMetadataDict: [UUID: ImageMetadata] = [:]
    
    //MARK: - Initialization
    
    required init(interactor: RichTextViewInteractor) {
        
        self.interactor = interactor
        super.init(frame: .zero, textContainer: nil)

        setup()
        
        self.isEditable = interactor.isEditable
    }
    
    required init?(coder: NSCoder) {
        
        self.interactor = RichTextViewInteractor(isEditable: true)
        super.init(coder: coder)
        
        setup()
    }
    
    //MARK: - Setup
    
    private func setup() {
        
        interactor.isSetupInProgress = true
        defer {
            interactor.isSetupInProgress = false
        }
        
        interactorSetup()
        
        self.delegate = self
        
        if interactor.isEditable {
            
            interactions.forEach { interaction in
                if interaction is UIDropInteraction {
                    removeInteraction(interaction)
                }
            }
            
            self.addInteraction(UIDropInteraction(delegate: self))
            self.isSelectable = true
        }
        
        setupPlaceholder()
        
        self.textContainerInset = UIEdgeInsets(top: textContainerInset.top + 4.0,
                                               left: textContainerInset.left,
                                               bottom: textContainerInset.bottom,
                                               right: textContainerInset.right)
        
        if interactor.document.currentText.length > 0 {
            /// Sometimes SwiftUI creates new UIViewRepresentable and our current text dissappears.
            /// This will save the state.
            self.attributedText = interactor.document.currentText
            textViewDidChange(self)
            
            /// We need delay because `frame` is probably still not correctly set up.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.contentOffset = self.interactor.contentOffset
            }
        }
    }
    
    var placeholderLabel: UILabel!
    
    private func setupPlaceholder() {
        
        placeholderLabel = UILabel()
        placeholderLabel.text = "Enter notes..."
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.sizeToFit()
        addSubview(placeholderLabel)
        placeholderLabel.frame.origin = CGPoint(x: 8, y: 12)
    }
    
    //MARK: - Interactor
    
    private func interactorSetup() {
                
        interactor.textView = self
        
        interactor.onTextLoaded = { [weak self] text in
            guard let self else { return }
            self.attributedText = text
            /// Trigger placeholder change.
            self.textViewDidChange(self)
        }
        
        interactor.onTextAttributesChanged = { [weak self] attributes, insertNewList in
            self?.updateTextAttributes(attributes, insertNewList: insertNewList)
        }
        
        updateTextAttributes(interactor.textAttributes, insertNewList: false)
    }
    
    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        interactor.isTextViewFirstResponder = result
        return result
    }
    
    @discardableResult
    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        interactor.isTextViewFirstResponder = result
        return result
    }
    
    //MARK: - Paste
    
    public override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        
        itemProviders.contains {
            $0.canLoadObject(ofClass: UIImage.self) ||
            $0.canLoadObject(ofClass: NSAttributedString.self) ||
            $0.canLoadObject(ofClass: NSString.self)
        }
    }
    
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    public override func paste(_ sender: Any?) {
        
        let itemProviders = UIPasteboard.general.itemProviders
        
        for provider in itemProviders where provider.canLoadObject(ofClass: UIImage.self) {
            
            provider.loadObject(ofClass: UIImage.self) { object, error in
                guard let image = object as? UIImage else { return }
                
                DispatchQueue.main.async {
                    self.interactor.insertImage(image)
                }
            }
        }
        
        super.paste(sender)
    }
    
    //MARK: - Text Attributes Updates
    
    private func updateTextAttributes(_ attributes: TextAttributes, insertNewList: Bool) {
        guard interactor.isEditable else { return }
        
        guard let textRange = self.selectedTextRange else { return }
        
        let location = offset(from: beginningOfDocument, to: textRange.start)
        let length = offset(from: textRange.start, to: textRange.end)
        let nsRange = NSRange(location: location, length: length)
        
        let newAttributes = attributes.toAttributedStringKeyDict()
        textStorage.addAttributes(newAttributes, range: nsRange)
        
        // nsRange.length == 0,
        if let paragraphRange = getParagraphRange(at: nsRange.location) {
            
            let attributes = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle, paragraphStyle.textLists.count > 0 {
                
                /// This way we remove list if it's empty.
                if paragraphRange.length > 0 && insertNewList == false {
                    textStorage.addAttributes(newAttributes, range: paragraphRange)
                    
                    let paragraphText = (textStorage.string as NSString).substring(with: paragraphRange)
                    if paragraphText == RichTextConstants.zeroWidthSpace {
                        textStorage.replaceCharacters(in: paragraphRange, with: "")
                    }
                }
            }
        }
        
        /// We need to update our `TextAttributes` because when we apply bold then the font also changes.
        /// And when we remove bold we have to revert the font too.
        attributes.updateWith(attributes: newAttributes)
        
        self.typingAttributes = attributes.toAttributedStringKeyDict()
        
        // nsRange.length == 0 &&
        if insertNewList && nsRange.location <= textStorage.length {
            
            var isParagraphEmpty: Bool = true
            let paragraphRange = getParagraphRange(at: nsRange.location)
            
            if let paragraphRange {
                let paragraphText = (textStorage.string as NSString).substring(with: paragraphRange)
                isParagraphEmpty = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            if isParagraphEmpty {
                
                let zwsAttributedString = NSAttributedString(
                    string: RichTextConstants.zeroWidthSpace,
                    attributes: newAttributes
                )
                
                ignoreDidChangeSelection = true
                // Insert directly into text storage
                textStorage.insert(zwsAttributedString, at: nsRange.location)
                
                // Update cursor position after insertion
                selectedRange = NSRange(location: nsRange.location + 1, length: 0)
            } else if let paragraphRange, isParagraphEmpty == false {
                textStorage.addAttributes(newAttributes, range: paragraphRange)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.ignoreDidChangeSelection = false
            }
        }
    }
    
    //MARK: - Deleting
    
    /// This is necessary in order to delete the list from attributes.
    
    public override func deleteBackward() {
        let currentRange = selectedRange
        
        // Handle list-specific deletion logic
        if shouldHandleListDeletion(at: currentRange) {
            handleListDeletion(at: currentRange)
            return
        }
        
        // Handle normal deletion with attribute inheritance
        handleNormalDeletion(at: currentRange)
    }
    
    private func shouldHandleListDeletion(at range: NSRange) -> Bool {
        guard range.location > 0 && range.length == 0 else { return false }
        
        // Check bounds before accessing attributes
        guard range.location < textStorage.length else { return false }
        
        let attributes = textStorage.attributes(at: range.location, effectiveRange: nil)
        guard let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle,
              !paragraphStyle.textLists.isEmpty else { return false }
        
        guard let paragraphRange = getParagraphRange(at: range.location) else {
            return false
        }
        
        // Additional safety check for paragraph range
        guard paragraphRange.location + paragraphRange.length <= textStorage.length else { return false }
        
        let paragraphText = textStorage.attributedSubstring(from: paragraphRange).string
        
        return paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleListDeletion(at range: NSRange) {
        guard let paragraphRange = getParagraphRange(at: range.location) else {
            return
        }
        removeListFormatting(at: paragraphRange)
    }
    
    private var ignoreDidChangeSelection = false
    
    private func handleNormalDeletion(at range: NSRange) {
        var deletedCharAttributes: [NSAttributedString.Key: Any]?
        
        // Capture attributes of character about to be deleted
        if range.length == 0 && range.location > 0 {
            deletedCharAttributes = textStorage.attributes(at: range.location - 1, effectiveRange: nil)
        }
        
        ignoreDidChangeSelection = true
        // Perform the deletion
        super.deleteBackward()
        ignoreDidChangeSelection = false
        
        // Update attributes to match deleted character
        if let attrs = deletedCharAttributes {
            typingAttributes = attrs
            interactor.textAttributes.updateWith(attributes: attrs)
        }
    }
    
    private func getParagraphRange(at location: Int) -> NSRange? {
        let text = textStorage.string as NSString
        guard text.length > 0 else {
            return nil //NSRange(location: 0, length: 0)
        }
        
        let safeLocation = max(0, min(location, text.length - 1))
        return text.paragraphRange(for: NSRange(location: safeLocation, length: 0))
    }
    
    private func removeListFormatting(at range: NSRange) {
        // Get current paragraph style and make a mutable copy
        guard let currentStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle,
              let newParagraphStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle,
              currentStyle.textLists.isEmpty == false else {
            return
        }
        
        // Remove only the textLists, keeping everything else
        newParagraphStyle.textLists = []
        newParagraphStyle.headIndent = 0  // Reset indentation too
        
        textStorage.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
        
        // Get ALL current attributes (including font, color, etc.) and preserve them
        let currentLocation = selectedRange.location
        var updatedAttributes: [NSAttributedString.Key: Any]
        
        if currentLocation < attributedText.length {
            updatedAttributes = attributedText.attributes(at: currentLocation, effectiveRange: nil)
        } else if currentLocation > 0 {
            updatedAttributes = attributedText.attributes(at: currentLocation - 1, effectiveRange: nil)
        } else {
            // Fallback to typing attributes
            updatedAttributes = typingAttributes
        }
        
        // Make sure the paragraph style in the attributes is the updated one (without list)
        updatedAttributes[.paragraphStyle] = newParagraphStyle
        
        ignoreDidChangeSelection = true
        
        // Update typing attributes with ALL attributes (preserving font, color, etc.)
        typingAttributes = updatedAttributes
        
        // Update interactor with the complete attribute set
        interactor.textAttributes.updateWith(attributes: updatedAttributes)
        
        // In-place removal of ZWS from the paragraph range
        
        defer {
            ignoreDidChangeSelection = false
        }
        
        guard let paragraphRange = getParagraphRange(at: range.location) else {
            return
        }
        
        let zws = RichTextConstants.zeroWidthSpace
        var didDeleteZWS = false
        
        // Iterate backwards to avoid index shifting
        let paragraphString = textStorage.string as NSString
        for i in (paragraphRange.location..<NSMaxRange(paragraphRange)).reversed() {
            let char = paragraphString.substring(with: NSRange(location: i, length: 1))
            if char == zws {
                textStorage.deleteCharacters(in: NSRange(location: i, length: 1))
                didDeleteZWS = true
            }
        }
        
        if didDeleteZWS {
            let newCursor = min(max(0, range.location), textStorage.length)
            selectedRange = NSRange(location: newCursor, length: 0)
        }
    }
}

//MARK: - UITextViewDelegate

extension RichTextView: UITextViewDelegate {
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard interactor.isEditable else { return }
        
        guard ignoreDidChangeSelection == false,
              let range = textView.selectedTextRange else {
            return
        }
        
        let offset = textView.offset(from: textView.beginningOfDocument, to: range.start)
        
        let location = textView.offset(from: beginningOfDocument, to: range.start)
        let length = textView.offset(from: range.start, to: range.end)
        let nsRange = NSRange(location: location, length: length)
        
        // Try to get attributes from the character to the left of the caret
        let adjustedLocation: Int
        if offset > 0 && nsRange.length <= 1 {
            adjustedLocation = offset - 1
        } else if offset < textView.attributedText.length {
            adjustedLocation = offset
        } else {
            interactor.textAttributes.updateWith(attributes: textView.typingAttributes)
            return
        }
        
        let attrs = textView.attributedText.attributes(at: adjustedLocation, effectiveRange: nil)
        textView.typingAttributes = attrs
        interactor.textAttributes.updateWith(attributes: attrs)
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        placeholderLabel?.isHidden = textView.attributedText.length != 0
        interactor.document.textChanged(textView.attributedText)
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard interactor.isEditable else { return false }
        
        // Get the attributed text in the range that is about to be replaced
        let attributedSubstring = textView.attributedText.attributedSubstring(from: range)
        
        var metadatas: [ImageMetadata] = []

        attributedSubstring.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedSubstring.length)) { value, _, _ in
            if let attachment = value as? ImageMetadataTextAttachment, let metadata = attachment.metadata {
                metadatas.append(metadata)
            }
        }

        if metadatas.isEmpty == false {
            interactor.imagesWereDeleted(metadatas: metadatas)
        }
        
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        interactor.contentOffset = scrollView.contentOffset
    }
}
