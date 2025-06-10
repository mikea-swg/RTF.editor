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
    
    public var interactor: RichTextViewInteractor? {
        didSet {
            interactorSetup()
        }
    }
    
    internal var imageMetadataDict: [UUID: ImageMetadata] = [:]
    
    //MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        self.addInteraction(UIDropInteraction(delegate: self))
        self.delegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.addInteraction(UIDropInteraction(delegate: self))
        self.delegate = self
    }
    
    //MARK: - Interactor
    
    private func interactorSetup() {
        
        guard let interactor else { return }
        
        interactor.onLoadFile = { [weak self] filename in
            try? self?.loadRTFD(filename: filename)
        }
        
        interactor.onLoadFileAtUrl = { [weak self] url in
            try self?.loadRTFD(url: url)
        }
        
        interactor.onExportToFile = { [weak self] filename in
            try? self?.exportToRTFD(filename: filename)
        }
        
        interactor.onExport = { [weak self] in
            self?.exportToRTFD()
        }
        
        interactor.onClearText = { [weak self] in
            self?.attributedText = NSAttributedString(string: "")
            self?.imageMetadataDict.removeAll()
        }
        
        interactor.onImageMetadataChanged = { [weak self] metadata in
            self?.updateImageMetadata(metadata)
        }
        
        interactor.onDeleteImageWithMetadata = { [weak self] metadata in
            self?.deleteImageWithMetadata(metadata)
        }
        
        interactor.onTextAttributesChanged = { [weak self] attributes, insertNewList in
            self?.updateTextAttributes(attributes, insertNewList: insertNewList)
        }
        
        updateTextAttributes(interactor.textAttributes, insertNewList: false)
    }
    
    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        interactor?.isTextViewFirstResponder = result
        return result
    }
    
    @discardableResult
    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        interactor?.isTextViewFirstResponder = result
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
                    self.insertImage(image)
                }
            }
        }
        
        super.paste(sender)
    }
    
    //MARK: - Import
    
    func loadRTFD(filename: String) throws {
        
        let result = try TextViewImportExport.loadTextViewFromRTF(filename: filename)
        
        self.imageMetadataDict = result
            .metadata
            .reduce(into: [UUID: ImageMetadata](), { partialResult, metadata in
                partialResult[metadata.id] = metadata
            })
        
        let newString = replaceTextAttachments(in: result.text)
        self.attributedText = newString
    }

    func loadRTFD(url: URL) throws {
        
        let result = try TextViewImportExport.loadTextViewFromRTF(url: url)
        
        self.imageMetadataDict = result
            .metadata
            .reduce(into: [UUID: ImageMetadata](), { partialResult, metadata in
                partialResult[metadata.id] = metadata
            })
        
        let newString = replaceTextAttachments(in: result.text)
        self.attributedText = newString
    }
    
    internal func replaceTextAttachments(in attributedString: NSAttributedString) -> NSAttributedString {
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        
        let range = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let originalAttachment = value as? NSTextAttachment,
                  let fileWrapper = originalAttachment.fileWrapper,
                  let filename = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(filename),
                  let metadata = self.imageMetadataDict[uuid] else {
                return
            }
            
            guard originalAttachment is MetadataTextAttachment == false else { return }
            
            // Create new styled attachment
            let styledAttachment = MetadataTextAttachment()
            styledAttachment.fileWrapper = fileWrapper
            styledAttachment.metadata = metadata
            styledAttachment.onTap = { [weak self] metadata in
                self?.interactor?.inspectorState = .image(metadata: metadata)
            }
            
            // Replace the attachment
            mutableString.addAttribute(.attachment, value: styledAttachment, range: attachmentRange)
        }
        
        return mutableString
    }
    
    //MARK: - Export
    
    func exportToRTFD(filename: String) throws {
        
        guard let attributedText else { return }
        
        try TextViewImportExport.exportTextViewToRTF(attributedText: attributedText, imageMetadataDict: imageMetadataDict, filename: filename)
        imageMetadataDict.removeAll()
        self.attributedText = NSAttributedString(string: "")
    }

    func exportToRTFD() -> RTFDDocument? {
        
        guard let attributedText else {
            return nil
        }
        
        let document = RTFDDocument(attributedString: attributedText, imageMetadataDict: imageMetadataDict)
        return document
    }
    
    //MARK: - Metadata Updates
    
    private func updateImageMetadata(_ metadata: ImageMetadata) {
        // Update the stored metadata
        imageMetadataDict[metadata.id] = metadata
        
        // Find and update the specific attachment
        updateAttachmentWithId(metadata.id, newMetadata: metadata)
    }
    
    private func updateAttachmentWithId(_ id: UUID, newMetadata: ImageMetadata) {
        guard let attributedText = self.attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        let range = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let attachment = value as? MetadataTextAttachment,
                  let fileWrapper = attachment.fileWrapper,
                  let filename = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(filename),
                  uuid == id else {
                return
            }
            
            // Update the metadata in the attachment
            attachment.metadata = newMetadata
            
            // Force the view provider to reload by invalidating the layout
            self.invalidateAttachmentAtRange(attachmentRange)
            
            // Stop enumeration since we found our attachment
            stop.pointee = true
        }
    }
    
    private func invalidateAttachmentAtRange(_ range: NSRange) {
        // For UITextView, the most reliable approach is to trigger a layout update
        // The attachment view providers will be recreated automatically
        
        DispatchQueue.main.async {
            // Method 1: Force layout invalidation
            self.setNeedsLayout()
            self.layoutIfNeeded()
            
            // Method 2: If Method 1 doesn't work reliably, use this approach:
            // Store current state
            let selectedRange = self.selectedRange
            let scrollPosition = self.contentOffset
            
            // Trigger a text change notification to force refresh
            self.textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
            
            // Restore state
            self.selectedRange = selectedRange
            self.contentOffset = scrollPosition
        }
    }
    
    //MARK: - Text Attributes Updates
    
    private func updateTextAttributes(_ attributes: TextAttributes, insertNewList: Bool) {
        
        guard let textRange = self.selectedTextRange else { return }
        
        let location = offset(from: beginningOfDocument, to: textRange.start)
        let length = offset(from: textRange.start, to: textRange.end)
        let nsRange = NSRange(location: location, length: length)
        
        let newAttributes = attributes.toAttributedStringKeyDict()
        textStorage.addAttributes(newAttributes, range: nsRange)
        
        if nsRange.length == 0, let paragraphRange = getParagraphRange(at: nsRange.location) {
            
            let attributes = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle, paragraphStyle.textLists.count > 0 {
                
                /// This way we remove list if it's empty.
                if paragraphRange.length > 0 {
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
        
        if selectedRange.length == 0 &&
            insertNewList,
           nsRange.location <= textStorage.length {
            
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
            interactor?.textAttributes.updateWith(attributes: attrs)
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
        interactor?.textAttributes.updateWith(attributes: updatedAttributes)
        
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

    //MARK: - Image Deleting
    
    private func deleteImageWithMetadata(_ metadata: ImageMetadata) {
        guard let attributedText = self.attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        let range = NSRange(location: 0, length: mutableString.length)
        var attachmentRangeToDelete: NSRange?
        
        // Find the attachment with matching metadata
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let attachment = value as? MetadataTextAttachment,
                  let fileWrapper = attachment.fileWrapper,
                  let filename = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(filename),
                  uuid == metadata.id else {
                return
            }
            
            attachmentRangeToDelete = attachmentRange
            stop.pointee = true
        }
        
        // Delete the attachment if found
        guard let rangeToDelete = attachmentRangeToDelete else { return }
        
        // Store current selection and scroll position
        let currentSelection = selectedRange
        let scrollPosition = contentOffset
        
        // Remove the attachment from text storage
        textStorage.deleteCharacters(in: rangeToDelete)
        
        // Clean up metadata
        imageMetadataDict.removeValue(forKey: metadata.id)
        
        // Adjust selection if it was after the deleted attachment
        let adjustedSelection: NSRange
        if currentSelection.location > rangeToDelete.location {
            let newLocation = max(rangeToDelete.location, currentSelection.location - rangeToDelete.length)
            adjustedSelection = NSRange(location: newLocation, length: currentSelection.length)
        } else {
            adjustedSelection = currentSelection
        }
        
        // Restore selection and scroll position
        selectedRange = adjustedSelection
        contentOffset = scrollPosition
        
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
    }
}

//MARK: - UITextViewDelegate

extension RichTextView: UITextViewDelegate {
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        
        guard ignoreDidChangeSelection == false,
              let range = textView.selectedTextRange else {
            return
        }
        
        print("textViewDidChangeSelection")
        
//        let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
//        if location < textView.attributedText.length {
//            
//            let attrs = textView.attributedText.attributes(at: location, effectiveRange: nil)
//            interactor?.textAttributes.updateWith(attributes: attrs)
//        }
        
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
            interactor?.textAttributes.updateWith(attributes: textView.typingAttributes)
            return
        }
        
        let attrs = textView.attributedText.attributes(at: adjustedLocation, effectiveRange: nil)
        textView.typingAttributes = attrs
        interactor?.textAttributes.updateWith(attributes: attrs)
    }
}
