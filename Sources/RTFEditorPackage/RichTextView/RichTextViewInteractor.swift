//
//  RichTextViewInteractor.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import Observation
import UIKit
import Combine

@Observable
public final class RichTextViewInteractor {
    
    public let isEditable: Bool
    weak var textView: RichTextView?
    
    public private(set) var textAttributes = TextAttributes()
    
    fileprivate enum DocumentLocation {
        case none
        case filename(_ name: String, _ fileMetadata: FileMetadata)
        case fileURL(_ fileURL: URL, _ fileMetadata: FileMetadata)
    }
    
    class Document {
        
        fileprivate(set) var currentText: NSAttributedString
        fileprivate(set) var imageMetadataDict: [UUID: ImageMetadata] = [:]
        fileprivate var documentLocation: DocumentLocation
        
        fileprivate init(currentText: NSAttributedString, imageMetadataDict: [UUID : ImageMetadata], documentLocation: DocumentLocation) {
            self.currentText = currentText
            self.imageMetadataDict = imageMetadataDict
            self.documentLocation = documentLocation
        }
        
        fileprivate func clearContent() {
            currentText = NSAttributedString(string: "")
            imageMetadataDict = [:]
        }
        
        func textChanged(_ newText: NSAttributedString) {
            currentText = newText
        }
    }
    
    var document: RichTextViewInteractor.Document
  
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
        
    @ObservationIgnored
    public var autoSave: Bool = true
    
    @ObservationIgnored
    private var saveTimer: Timer?
    
    @ObservationIgnored
    var onSaveError: ((Error) -> Void)?

    @ObservationIgnored
    public let onSaveSubject = PassthroughSubject<Void, Never>()
    
    @ObservationIgnored
    var isSetupInProgress: Bool = false
    
    @ObservationIgnored
    var contentOffset: CGPoint = .zero
    
    //MARK: - Init
    
    public init(isEditable: Bool) {
        print("RichTextViewInteractor init")
        self.isEditable = isEditable
        
        self.document = RichTextViewInteractor.Document(currentText: NSAttributedString(string: ""),
                                                        imageMetadataDict: [:],
                                                        documentLocation: .none)
        
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
        
        isSetupInProgress = true
        defer {
            isSetupInProgress = false
        }
        
        let result = try RtfDataImportExport.loadFromRTFD(filename: filename)
        onTextLoadResult(result: result, documentLocation: .filename(filename, result.fileMetadata))
    }
    
    public func loadRTFD(url: URL) throws {

        isSetupInProgress = true
        defer {
            isSetupInProgress = false
        }
        let result = try RtfDataImportExport.loadFromRTFD(url: url)
        onTextLoadResult(result: result, documentLocation: .fileURL(url, result.fileMetadata))
    }
    
    private func onTextLoadResult(result: RtfDataImportExport.LoadResult, documentLocation: DocumentLocation) {
        
        sinkToAttachmentsTapAction(attachments: result.attachments)
        self.document = Document(currentText: result.text, imageMetadataDict: result.metadata, documentLocation: documentLocation)
        onTextLoaded?(result.text)
    }
    
    private func sinkToAttachmentsTapAction(attachments: [ImageMetadataTextAttachment]) {
        guard isEditable else { return }
        
        attachments.forEach { [weak self] attachment in
            attachment.onTap = { [weak self] metadata in
                self?.inspectorState = .image(metadata: metadata)
            }
        }
    }
    
    //MARK: - Export
    
    private func fileMetadata() -> FileMetadata {
        
        let fileMetadata: FileMetadata? = switch document.documentLocation {
        case .fileURL(_, let metadata):
            metadata
        case .filename(_, let metadata):
            metadata
        case .none:
            nil
        }
        
        let uFileMetadata = fileMetadata?.withNewUpdatedAt() ?? FileMetadata(createdAt: Date(), updatedAt: Date())
        return uFileMetadata
    }
    
    public func exportToRTFD(filename: String, clearEditor: Bool) throws {
        
        let uFileMetadata = fileMetadata()
        
        try RtfDataImportExport.exportToRTFD(attributedText: document.currentText,
                                              imageMetadataDict: document.imageMetadataDict,
                                              fileMetadata: uFileMetadata,
                                              filename: filename)
        
        if clearEditor {
            document.clearContent()
            onTextLoaded?(document.currentText)
        }
    }
    
    public func exportToRTFD(fileURL: URL, clearEditor: Bool) throws {
        
        let uFileMetadata = fileMetadata()
        
        try RtfDataImportExport.exportToRTFD(attributedText: document.currentText,
                                              imageMetadataDict: document.imageMetadataDict,
                                              fileMetadata: uFileMetadata,
                                              fileURL: fileURL)
        
        if clearEditor {
            document.clearContent()
            onTextLoaded?(document.currentText)
        }
    }
    
    public func exportAsRTFDDocument() -> RTFDDocument {
        
        let uFileMetadata = fileMetadata()
        
        let document = RTFDDocument(attributedString: document.currentText,
                                    imageMetadataDict: document.imageMetadataDict,
                                    fileMetadata: uFileMetadata)
        return document
    }
    
    //MARK: - Text Attributes
    
    @MainActor
    public func textAttributesChanged(attributes: TextAttributes, insertNewList: Bool) {
        guard isEditable else { return }
        
        onTextAttributesChanged?(attributes, insertNewList)
        if let text = textView?.attributedText {
            /// Trigger save.
            self.document.currentText = text
        }
    }
    
    //MARK: - Metadata
    
    @MainActor
    public func updateImageMetadata(_ metadata: ImageMetadata) {
        guard isEditable else { return }
        
        // Update the stored metadata
        self.document.imageMetadataDict[metadata.id] = metadata
        
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
            guard let attachment = value as? ImageMetadataTextAttachment,
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
        guard isEditable else { return }
        
        guard let textView = self.textView else { return }
        
        let onTap: (ImageMetadata) -> Void = { [weak self] metadata in
            self?.inspectorState = .image(metadata: metadata)
        }
        
        let attachment = TextAttachmentFactory.createAttributedStringFromImage(originalImage,
                                                                               textView: textView,
                                                                               onTap: onTap,
                                                                               existingMetadata: nil)
        
        document.imageMetadataDict[attachment.medatadata.id] = attachment.medatadata
        
        // Insert at selected range
        if let selectedRange = textView.selectedTextRange {
            
            let location = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.insert(attachment.string, at: location)
            
            let result = TextInteraction.replaceTextAttachments(in: mutableText, imagesMetadataDict: document.imageMetadataDict)
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
            
            let result = TextInteraction.replaceTextAttachments(in: mutableText, imagesMetadataDict: document.imageMetadataDict)
            textView.attributedText = result.text
            sinkToAttachmentsTapAction(attachments: result.attachments)
        }
        
        document.currentText = textView.attributedText
        saveChanges()
    }
    
    //MARK: - Image Delete
    
    internal func imagesWereDeleted(metadatas: [ImageMetadata]) {
        guard isEditable else { return }
        
        for item in metadatas {
            document.imageMetadataDict.removeValue(forKey: item.id)
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
        guard isEditable else { return }
        
        guard let textView, let attributedText = textView.attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        let range = NSRange(location: 0, length: mutableString.length)
        var attachmentRangeToDelete: NSRange?
        
        // Find the attachment with matching metadata
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let attachment = value as? ImageMetadataTextAttachment,
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
        
        /// Do not adjust selectedRange because it breaks rendering.
        
        // Store current selection and scroll position
//        let currentSelection = textView.selectedRange
//        let scrollPosition = textView.contentOffset
        
        // Remove the attachment from text storage
        textView.textStorage.deleteCharacters(in: rangeToDelete)
        
        // Clean up metadata
        document.imageMetadataDict.removeValue(forKey: metadata.id)
        
//        // Adjust selection if it was after the deleted attachment
//        let adjustedSelection: NSRange
//        if currentSelection.location > rangeToDelete.location {
//            let newLocation = max(rangeToDelete.location, currentSelection.location - rangeToDelete.length)
//            adjustedSelection = NSRange(location: newLocation, length: currentSelection.length)
//        } else {
//            adjustedSelection = currentSelection
//        }
//        
//        // Restore selection and scroll position
//        textView.selectedRange = adjustedSelection
//        textView.contentOffset = scrollPosition
        
        // Force layout update
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        
        textView.textViewDidChange(textView) // Trigger placeholder.
        
        self.document.currentText = textView.attributedText
        
        scheduleSaveTimer()
    }
}

extension RichTextViewInteractor {
    
    func scheduleSaveTimer() {
        guard isEditable, isSetupInProgress == false else { return }
        
        switch document.documentLocation {
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
        guard isEditable else { return }
        
        print("Saving changes")
        
        saveTimer?.invalidate()
        saveTimer = nil
        
        do {
            switch self.document.documentLocation {
            case .none:
                return
            case .fileURL(let url, let fileMetadata):
                try self.exportToRTFD(fileURL: url, clearEditor: false)
            case .filename(let name, let fileMetadata):
                try self.exportToRTFD(filename: name, clearEditor: false)
            }
            
            onSaveSubject.send()
        } catch {
            self.onSaveError?(error)
        }
    }
}
