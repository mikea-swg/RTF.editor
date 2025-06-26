//
//  TextViewDataHandler.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation
import UIKit

public struct RtfDataImportExport {
    
    private static let imageMetadataName = "image_metadata.json"
    private static let fileMetadataName = "file_metadata.json"
    
    static func exportFileWrapper(attributedText: NSAttributedString,
                                  imageMetadataDict: [UUID: ImageMetadata],
                                  fileMetadata: FileMetadata) throws -> FileWrapper {
        
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
                
        let imagesFileWrapper = try createFileWrapperFor(encodable: Array(imageMetadataDict.values), fileName: imageMetadataName)
        rtfdWrapper.addFileWrapper(imagesFileWrapper)
        filterOutUnusedImageWrappers(imageMetadataDict: imageMetadataDict, fileWrapper: rtfdWrapper)
        
        let fileMetadataWrapper = try createFileWrapperFor(encodable: fileMetadata, fileName: fileMetadataName)
        rtfdWrapper.addFileWrapper(fileMetadataWrapper)

        return rtfdWrapper
    }
    
    private static func createFileWrapperFor<T: Encodable>(encodable object: T, fileName: String) throws -> FileWrapper {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(object)
        
        let jsonWrapper = FileWrapper(regularFileWithContents: jsonData)
        jsonWrapper.preferredFilename = fileName
        return jsonWrapper
    }
    
    private static func filterOutUnusedImageWrappers(imageMetadataDict: [UUID: ImageMetadata], fileWrapper: FileWrapper) {
        
        // Filter out unused image wrappers
        let validImageFilenames = imageMetadataDict
            .keys
            .map({ TextAttachmentFactory.createFileWrapperName(id: $0) })
        
        let fileWrappers = (fileWrapper.fileWrappers ?? [:])
            .filter({
                $0.key != imageMetadataName && $0.key != fileMetadataName && isImage(filename: $0.key)
            })
        
        for (filename, wrapper) in fileWrappers {
            if validImageFilenames.contains(filename) == false {
                fileWrapper.removeFileWrapper(wrapper)
            }
        }
    }
    
    static func exportToRTFD(attributedText: NSAttributedString,
                             imageMetadataDict: [UUID: ImageMetadata],
                             fileMetadata: FileMetadata,
                             filename: String) throws {
                
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let uFilename = filename.contains(RichTextConstants.rtfdslExtension) ? filename : "\(filename)\(RichTextConstants.rtfdslExtension)"
        let fileURL = documentsURL.appendingPathComponent("\(uFilename)", isDirectory: true)
        
        try exportToRTFD(attributedText: attributedText,
                         imageMetadataDict: imageMetadataDict,
                         fileMetadata: fileMetadata,
                         fileURL: fileURL)
    }

    public static func exportToRTFD(attributedText: NSAttributedString,
                                    imageMetadataDict: [UUID: ImageMetadata],
                                    fileMetadata: FileMetadata,
                                    fileURL: URL) throws {
        
        let rtfdWrapper = try self.exportFileWrapper(attributedText: attributedText,
                                                     imageMetadataDict: imageMetadataDict,
                                                     fileMetadata: fileMetadata)
        
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
        let attachments: [ImageMetadataTextAttachment]
        let fileMetadata: FileMetadata
    }
    
    static func loadFromRTFD(fileWrapper: FileWrapper) throws -> LoadResult {
        
        // Write temporarily to disk (RTFD requires directory structure)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(RichTextConstants.rtfdslExtension)
        
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
        
        let imagesMetadataDict = try loadImagesMetadata(url: url)
        let replaced = TextInteraction.replaceTextAttachments(in: attributedString, imagesMetadataDict: imagesMetadataDict)
        
        let fileMetadata = try loadFileMetadata(url: url)
        
        return LoadResult(text: replaced.text,
                          metadata: imagesMetadataDict,
                          attachments: replaced.attachments,
                          fileMetadata: fileMetadata)
    }
    
    private static func loadImagesMetadata(url: URL) throws -> [UUID: ImageMetadata] {
        
        let metadataURL = url.appendingPathComponent(imageMetadataName)
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return [:]
        }
                
        let data = try Data(contentsOf: metadataURL)
        let array = try JSONDecoder().decode([ImageMetadata].self, from: data)
        
        let metadataDict = array.reduce(into: [UUID: ImageMetadata](), { partialResult, metadata in
            partialResult[metadata.id] = metadata
        })
        return metadataDict
    }
    
    public enum LoadError: Error {
        case fileMetadataIsMissing
    }
    
    public static func loadFileMetadata(url: URL) throws -> FileMetadata {
        
        let metadataURL = url.appendingPathComponent(fileMetadataName)

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw LoadError.fileMetadataIsMissing
        }
        
        let data = try Data(contentsOf: metadataURL)
        let result = try JSONDecoder().decode(FileMetadata.self, from: data)
        return result
    }
}


