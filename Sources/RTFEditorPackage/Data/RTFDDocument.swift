//
//  MyRTFDocument.swift
//  RTFEditor
//
//  Created by Josip Bernat on 09.06.2025..
//


import UniformTypeIdentifiers
import SwiftUI

public struct RTFDDocument: FileDocument, @unchecked Sendable {
    
    nonisolated(unsafe) public static var readableContentTypes: [UTType] = [.rtfd]
    nonisolated(unsafe) public static var writableContentTypes: [UTType] = [.rtfd]

    let attributedString: NSAttributedString
    let imageMetadataDict: [UUID: ImageMetadata]

    init(attributedString: NSAttributedString, imageMetadataDict: [UUID: ImageMetadata]) {
        self.attributedString = attributedString
        self.imageMetadataDict = imageMetadataDict
    }

    public init(configuration: ReadConfiguration) throws {
        let (attrText, imageMetadata) = try TextViewImportExport.loadFromRTFD(fileWrapper: configuration.file)
        self.attributedString = attrText
        self.imageMetadataDict = imageMetadata.reduce(into: [UUID: ImageMetadata](), { partialResult, metadata in
            partialResult[metadata.id] = metadata
        })
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try TextViewImportExport.exportFileWrapper(
            attributedText: attributedString,
            imageMetadataDict: imageMetadataDict
        )
    }

}
