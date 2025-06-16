//
//  TextViewDataHandler.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation
import UIKit

public struct TextViewImportExport {
    
    private static let metadataName = "metadata.json"
    
    static func exportFileWrapper(attributedText: NSAttributedString,
                                  imageMetadataDict: [UUID: ImageMetadata]) throws -> FileWrapper {
        
        let attributedText = removeZWSFromAttributedText(attributedText)
        
        let docAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtfd,
            .characterEncoding: String.Encoding.utf8
        ]
        
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        var rtfdWrapper: FileWrapper!
        do {
            rtfdWrapper = try attributedText.fileWrapper(from: fullRange, documentAttributes: docAttributes)
        } catch {
            throw error
        }
        
        let imagesJson: [[String: Any]] = imageMetadataDict
            .values
            .map({ $0.jsonDict() })
        
        let jsonData = try JSONSerialization.data(withJSONObject: imagesJson, options: [.prettyPrinted])
        
        let jsonWrapper = FileWrapper(regularFileWithContents: jsonData)
        jsonWrapper.preferredFilename = metadataName
        rtfdWrapper.addFileWrapper(jsonWrapper)
        
        // Filter out unused image wrappers
        let validImageFilenames = imageMetadataDict
            .keys
            .map({ TextAttachmentFactory.createFileWrapperName(id: $0) })
        
        for (filename, wrapper) in rtfdWrapper.fileWrappers ?? [:] {
            if filename != metadataName,
               isImage(filename: filename),
               validImageFilenames.contains(filename) == false {
                
                rtfdWrapper.removeFileWrapper(wrapper)
            }
        }
        
        return rtfdWrapper
    }
    
    static func exportToRTFD(attributedText: NSAttributedString,
                             imageMetadataDict: [UUID: ImageMetadata],
                             filename: String) throws {
                
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(filename)\(RichTextConstants.rtfdslExtension)", isDirectory: true)
        
        try exportToRTFD(attributedText: attributedText, imageMetadataDict: imageMetadataDict, fileURL: fileURL)
    }

    public static func exportToRTFD(attributedText: NSAttributedString,
                                    imageMetadataDict: [UUID: ImageMetadata],
                                    fileURL: URL) throws {
        
        let rtfdWrapper = try self.exportFileWrapper(attributedText: attributedText, imageMetadataDict: imageMetadataDict)
        try rtfdWrapper.write(to: fileURL, options: .atomic, originalContentsURL: nil)
    }
    
    // Helper to detect image files
    private static func isImage(filename: String) -> Bool {
        let lowercased = filename.lowercased()
        return lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".gif")
    }
    
    private static func removeZWSFromAttributedText(_ attributedText: NSAttributedString) -> NSAttributedString {
        let text = attributedText.string
        
        // Quick check - if no ZWS exists, return original
        guard text.contains(RichTextConstants.zeroWidthSpace) else {
            return attributedText
        }
        
        let mutableCopy = attributedText.mutableCopy() as! NSMutableAttributedString
        let nsText = text as NSString
        var zwsRanges: [NSRange] = []
        
        // Find all ZWS ranges at once
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length),
                                   options: [.byComposedCharacterSequences]) { substring, range, _, _ in
            if substring == RichTextConstants.zeroWidthSpace {
                zwsRanges.append(range)
            }
        }
        
        // Remove ZWS characters that have real content in their paragraph (work backwards)
        for zwsRange in zwsRanges.reversed() {
            let paragraphRange = nsText.paragraphRange(for: zwsRange)
            let paragraphText = nsText.substring(with: paragraphRange)
            let contentWithoutZWS = paragraphText.replacingOccurrences(of: RichTextConstants.zeroWidthSpace, with: "")
            
            // Only remove if there's real content beyond whitespace
            if !contentWithoutZWS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mutableCopy.deleteCharacters(in: zwsRange)
            }
        }
        
        return mutableCopy
    }
    
    //MARK: - Load
    
    struct LoadResult {
        let text: NSAttributedString
        let metadata: [UUID: ImageMetadata]
        let attachments: [MetadataTextAttachment]
    }
    
    static func loadFromRTFD(fileWrapper: FileWrapper) throws -> LoadResult {
        
        // Write temporarily to disk (RTFD requires directory structure)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("rtfd")
        
        try fileWrapper.write(to: tempURL, options: .atomic, originalContentsURL: nil)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return try loadFromRTFD(url: tempURL)
    }
    
    static func loadFromRTFD(filename: String) throws -> LoadResult {
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let rtfdDirectoryURL = documentsURL.appendingPathComponent("\(filename)\(RichTextConstants.rtfdslExtension)", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: rtfdDirectoryURL.path) else {
            print("RTF file does not exist at: \(rtfdDirectoryURL.path)")
            throw NSError(domain: "File error", code: 100)
        }
        
        let result = try loadFromRTFD(url: rtfdDirectoryURL)
        return result
    }
    
    static func loadFromRTFD(url: URL) throws -> LoadResult {
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("RTF file does not exist at: \(url.path)")
            throw NSError(domain: "File error", code: 100)
        }
        
        let attributedString = try NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )
        
        let metadataURL = url.appendingPathComponent(metadataName)
        var metadata: [[String: Any]]? = nil
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            metadata = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        }
        
        let imagesMetadata = metadata?
            .compactMap({
                ImageMetadata.fromJsonDict($0)
            })
            .reduce(into: [UUID: ImageMetadata](), { partialResult, item in
                partialResult[item.id] = item
            }) ?? [:]
        
        let replaced = replaceTextAttachments(in: attributedString, imagesMetadataDict: imagesMetadata)
        
        return LoadResult(text: replaced.text,
                          metadata: imagesMetadata,
                          attachments: replaced.attachments)
    }
    
    static func replaceTextAttachments(in attributedString: NSAttributedString, imagesMetadataDict: [UUID: ImageMetadata]) -> (text: NSAttributedString,
                                                                                                                               attachments: [MetadataTextAttachment]) {
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var attachments = [MetadataTextAttachment]()
        
        let range = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.attachment, in: range, options: []) { value, attachmentRange, stop in
            guard let originalAttachment = value as? NSTextAttachment,
                  let fileWrapper = originalAttachment.fileWrapper,
                  let filename = fileWrapper.filename,
                  let uuid = TextAttachmentFactory.metadataIdFromFileWrapperName(filename),
                  let metadata = imagesMetadataDict[uuid] else {
                return
            }
            
            guard originalAttachment is MetadataTextAttachment == false else { return }
            
            // Create new styled attachment
            let styledAttachment = MetadataTextAttachment()
            styledAttachment.fileWrapper = fileWrapper
            styledAttachment.metadata = metadata
            //            styledAttachment.onTap = { [weak self] metadata in
            //                interactor?.inspectorState = .image(metadata: metadata)
            //            }
            attachments.append(styledAttachment)
            
            // Replace the attachment
            mutableString.addAttribute(.attachment, value: styledAttachment, range: attachmentRange)
        }
        
        return (mutableString, attachments)
    }
}
