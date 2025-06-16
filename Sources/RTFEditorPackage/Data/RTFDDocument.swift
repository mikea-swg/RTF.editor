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

    init(attributedString: NSAttributedString, imageMetadataDict: [UUID: ImageMetadata]) {
        self.attributedString = attributedString
        self.imageMetadataDict = imageMetadataDict
    }

    public init(configuration: ReadConfiguration) throws {
        let result = try TextViewImportExport.loadFromRTFD(fileWrapper: configuration.file)
        self.attributedString = result.text
        self.imageMetadataDict = result.metadata
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try TextViewImportExport.exportFileWrapper(
            attributedText: attributedString,
            imageMetadataDict: imageMetadataDict
        )
    }
}
