//
//  TextViewDataHandler.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation
import UIKit

struct TextViewImportExport {
    
    private static let metadataName = "metadata.json"
    
    static func exportFileWrapper(attributedText: NSAttributedString, imageMetadataDict: [UUID: ImageMetadata]) throws -> FileWrapper {
        
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
    
    static func exportTextViewToRTF(attributedText: NSAttributedString,
                                    imageMetadataDict: [UUID: ImageMetadata],
                                    filename: String) throws {
        
        let rtfdWrapper = try self.exportFileWrapper(attributedText: attributedText, imageMetadataDict: imageMetadataDict)
                
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let rtfdDirectoryURL = documentsURL.appendingPathComponent("\(filename)\(RichTextConstants.rtfdExtension)", isDirectory: true)
        
        try rtfdWrapper.write(to: rtfdDirectoryURL, options: .atomic, originalContentsURL: nil)
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
    
    static func loadFromRTFD(fileWrapper: FileWrapper) throws -> (NSAttributedString, [ImageMetadata]) {

        // Write temporarily to disk (RTFD requires directory structure)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("rtfd")

        try fileWrapper.write(to: tempURL, options: .atomic, originalContentsURL: nil)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return try loadTextViewFromRTF(url: tempURL)
    }


    static func loadTextViewFromRTF(filename: String) throws -> (text: NSAttributedString, metadata: [ImageMetadata]) {
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let rtfdDirectoryURL = documentsURL.appendingPathComponent("\(filename)\(RichTextConstants.rtfdExtension)", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: rtfdDirectoryURL.path) else {
            print("RTF file does not exist at: \(rtfdDirectoryURL.path)")
            throw NSError(domain: "File error", code: 100)
        }
        
        let attributedString = try NSAttributedString(
            url: rtfdDirectoryURL,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )
        
        let metadataURL = rtfdDirectoryURL.appendingPathComponent(metadataName)
        var metadata: [[String: Any]]? = nil
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            metadata = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        }
        
        let imagesMetadata = metadata?
            .compactMap({
                ImageMetadata.fromJsonDict($0)
            }) ?? []
        
        return (attributedString, imagesMetadata)
    }

    static func loadTextViewFromRTF(url: URL) throws -> (text: NSAttributedString, metadata: [ImageMetadata]) {
                
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
            }) ?? []
        
        return (attributedString, imagesMetadata)
    }
}
