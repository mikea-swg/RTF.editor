//
//  RichTextViewInteractor.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import Observation
import UIKit

@Observable
public final class RichTextViewInteractor {
    
    weak var textView: RichTextView?
  
    @ObservationIgnored
    var onTextLoaded: ((_ text: NSAttributedString) -> Void)?
    
    @ObservationIgnored
    var onTextAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    
    public enum InspectorState {
        case closed
        case image(metadata: ImageMetadata)
        case text(attributes: TextAttributes)
    }
    
    private var _inspectorState: InspectorState = .closed
    public var inspectorState: InspectorState {
        get { _inspectorState }
        set {
            _inspectorState = newValue
            onInspectorStateChanged?(newValue)
        }
    }
    public var onInspectorStateChanged: ((_ newState: InspectorState) -> Void)?
    
    private var _isTextViewFirstResponder: Bool = false
    public var isTextViewFirstResponder: Bool {
        get { _isTextViewFirstResponder }
        set {
            _isTextViewFirstResponder = newValue
            onIsTextViewFirstResponderChanged?(newValue)
        }
    }
    
    @ObservationIgnored
    public var onIsTextViewFirstResponderChanged: ((_ newValue: Bool) -> Void)?
    
    public private(set) var textAttributes = TextAttributes()
    
    @ObservationIgnored
    var currentText: NSAttributedString {
        didSet {
            scheduleSaveTimer()
        }
    }
    
    @ObservationIgnored
    var imageMetadataDict: [UUID: ImageMetadata] = [:]
    
    @ObservationIgnored
    public var autoSave: Bool = true
    
    @ObservationIgnored
    private var saveTimer: Timer?
    
    @ObservationIgnored
    private var loadedTextFileURL: URL?
    
    private enum LoadedDocument {
        case none
        case filename(_ name: String)
        case fileURL(_ fileURL: URL)
    }
    
    @ObservationIgnored
    private var loadedDocument: LoadedDocument = .none
    
    @ObservationIgnored
    var onSaveError: ((Error) -> Void)?
    
    //MARK: - Init
    
    public init() {
        print("RichTextViewInteractor init")
        currentText = NSAttributedString(string: "")
    }
}

extension RichTextViewInteractor {
    
    func cleanupTempFiles(fileName: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let rtfdFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.absoluteString.contains(fileName) }
        
        rtfdFiles?.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
}

extension RichTextViewInteractor {
    
    //MARK: - Import
    
    public func loadRTFD(filename: String) throws {
        
        let result = try TextViewImportExport.loadFromRTFD(filename: filename)
        onTextLoadResult(result: result)
        
        loadedDocument = .filename(filename)
    }
    
    public func loadRTFD(url: URL) throws {

        let result = try TextViewImportExport.loadFromRTFD(url: url)
        onTextLoadResult(result: result)
        
        loadedDocument = .fileURL(url)
    }
    
    private func onTextLoadResult(result: TextViewImportExport.LoadResult) {
        
        sinkToAttachmentsTapAction(attachments: result.attachments)
        self.currentText = result.text
        self.imageMetadataDict = result.metadata
        onTextLoaded?(result.text)
    }
    
    private func sinkToAttachmentsTapAction(attachments: [MetadataTextAttachment]) {
        
        attachments.forEach { [weak self] attachment in
            attachment.onTap = { [weak self] metadata in
                self?.inspectorState = .image(metadata: metadata)
            }
        }
    }
    
    //MARK: - Export
    
    public func exportToRTFD(filename: String, clearEditor: Bool) throws {
        
        try TextViewImportExport.exportToRTFD(attributedText: currentText, imageMetadataDict: imageMetadataDict, filename: filename)
        
        if clearEditor {
            imageMetadataDict.removeAll()
            currentText = NSAttributedString(string: "")
            onTextLoaded?(currentText)
        }
    }
    
    public func exportToRTFD(fileURL: URL, clearEditor: Bool) throws {
        
        try TextViewImportExport.exportToRTFD(attributedText: currentText, imageMetadataDict: imageMetadataDict, fileURL: fileURL)
        
        if clearEditor {
            imageMetadataDict.removeAll()
            currentText = NSAttributedString(string: "")
            onTextLoaded?(currentText)
        }
    }
    
    public func exportAsRTFDDocument() -> RTFDDocument? {
        
        let document = RTFDDocument(attributedString: currentText, imageMetadataDict: imageMetadataDict)
        return document
    }
    
    //MARK: - Text Attributes
    
    public func textAttributesChanged(attributes: TextAttributes, insertNewList: Bool) {
        
        onTextAttributesChanged?(attributes, insertNewList)
        scheduleSaveTimer()
    }
    
    //MARK: - Metadata
    
    @MainActor
    public func updateImageMetadata(_ metadata: ImageMetadata) {
        // Update the stored metadata
        imageMetadataDict[metadata.id] = metadata
        
        // Find and update the specific attachment
        updateAttachmentWithId(metadata.id, newMetadata: metadata)
        
        scheduleSaveTimer()
    }
    
    @MainActor
    private func updateAttachmentWithId(_ id: UUID, newMetadata: ImageMetadata) {
        guard let textView, let attributedText = textView.attributedText else { return }
        
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
        
        guard let textView else { return }
        
        DispatchQueue.main.async {
            // Method 1: Force layout invalidation
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            
            // Method 2: If Method 1 doesn't work reliably, use this approach:
            // Store current state
            let selectedRange = textView.selectedRange
            let scrollPosition = textView.contentOffset
            
            // Trigger a text change notification to force refresh
            textView.textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
            
            // Restore state
            textView.selectedRange = selectedRange
            textView.contentOffset = scrollPosition
        }
    }
    
    //MARK: - Image Insert
    
    @MainActor
    func insertImage(_ originalImage: UIImage) {
        
        guard let textView = self.textView else { return }
        
        let onTap: (ImageMetadata) -> Void = { [weak self] metadata in
            self?.inspectorState = .image(metadata: metadata)
        }
        
        let attachment = TextAttachmentFactory.createAttributedStringFromImage(originalImage,
                                                                               textView: textView,
                                                                               onTap: onTap,
                                                                               existingMetadata: nil)
        
        imageMetadataDict[attachment.medatadata.id] = attachment.medatadata
        
        // Insert at selected range
        if let selectedRange = textView.selectedTextRange {
            
            let location = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.insert(attachment.string, at: location)
            
            let result = TextViewImportExport.replaceTextAttachments(in: mutableText, imagesMetadataDict: imageMetadataDict)
            textView.attributedText = result.text
            sinkToAttachmentsTapAction(attachments: result.attachments)
            
            // Restore cursor after the image
            if let newPosition = textView.position(from: selectedRange.start, offset: attachment.string.length) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        } else {
            // Fallback: Append to the end
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.append(attachment.string)
            
            let result = TextViewImportExport.replaceTextAttachments(in: mutableText, imagesMetadataDict: imageMetadataDict)
            textView.attributedText = result.text
            sinkToAttachmentsTapAction(attachments: result.attachments)
        }
        
        scheduleSaveTimer()
    }
    
    //MARK: - Image Delete
    
    internal func imagesWereDeleted(metadatas: [ImageMetadata]) {
        for item in metadatas {
            imageMetadataDict.removeValue(forKey: item.id)
        }
        
        switch inspectorState {
        case .image(let metadata):
            if metadatas.contains(where: { $0.id == metadata.id }) {
                inspectorState = .closed
                break
            }
        default:
            break
        }
        
        scheduleSaveTimer()
    }
    
    @MainActor
    public func deleteImageWithMetadata(_ metadata: ImageMetadata) {
        
        guard let textView, let attributedText = textView.attributedText else { return }
        
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
        let currentSelection = textView.selectedRange
        let scrollPosition = textView.contentOffset
        
        // Remove the attachment from text storage
        textView.textStorage.deleteCharacters(in: rangeToDelete)
        
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
        textView.selectedRange = adjustedSelection
        textView.contentOffset = scrollPosition
        
        // Force layout update
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        
        textView.textViewDidChange(textView) // Trigger placeholder.
        
        self.currentText = textView.attributedText
        
        scheduleSaveTimer()
    }
}

extension RichTextViewInteractor {
    
    func scheduleSaveTimer() {
        
        switch loadedDocument {
        case .none:
            return
        default:
            break
        }
             
        saveTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            
            guard let self else { return }
            saveChanges()
        }
    }
    
    public func saveChanges() {
        
        print("Saving changes")
        
        self.saveTimer = nil
        
        do {
            switch self.loadedDocument {
            case .none:
                return
            case .fileURL(let url):
                try self.exportToRTFD(fileURL: url, clearEditor: false)
            case .filename(let name):
                try self.exportToRTFD(filename: name, clearEditor: false)
            }
        } catch {
            self.onSaveError?(error)
        }
    }
}
