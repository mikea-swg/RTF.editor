//
//  MyRTFDocument.swift
//  RTFEditor
//
//  Created by Josip Bernat on 09.06.2025..
//


import UniformTypeIdentifiers
import SwiftUI

public struct RTFDDocument: FileDocument, @unchecked Sendable {
    
    nonisolated(unsafe) public static var readableContentTypes: [UTType] = [.rtfdsl]
    nonisolated(unsafe) public static var writableContentTypes: [UTType] = [.rtfdsl]

    let attributedString: NSAttributedString
    let imageMetadataDict: [UUID: ImageMetadata]
    let fileMetadata: FileMetadata

    init(attributedString: NSAttributedString,
         imageMetadataDict: [UUID: ImageMetadata],
         fileMetadata: FileMetadata) {
        
        self.attributedString = attributedString
        self.imageMetadataDict = imageMetadataDict
        self.fileMetadata = fileMetadata
    }

    public init(configuration: ReadConfiguration) throws {
        let result = try RtfDataImportExport.loadFromRTFD(fileWrapper: configuration.file)
        self.attributedString = result.text
        self.imageMetadataDict = result.metadata
        self.fileMetadata = result.fileMetadata
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try RtfDataImportExport.exportFileWrapper(
            attributedText: attributedString,
            imageMetadataDict: imageMetadataDict,
            fileMetadata: fileMetadata
        )
    }
}
