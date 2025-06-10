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
    
    var onLoadFile: ((_ filename: String) -> Void)?
    var onLoadFileAtUrl: ((URL) throws -> Void)?
    
    var onExportToFile: ((_ filename: String) -> Void)?
    var onExport: (() -> RTFDDocument?)?
    
    var onClearText: (() -> Void)?
    
    @ObservationIgnored
    var onImageMetadataChanged: ((ImageMetadata) -> Void)?
    
    @ObservationIgnored
    var onDeleteImageWithMetadata: ((ImageMetadata) -> Void)?
    
    @ObservationIgnored
    var onTextAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    
    @ObservationIgnored
    var onInsertList: ((_ textListMarkerFormat: NSTextList.MarkerFormat) -> Void)?
    
    enum InspectorState {
        case closed
        case image(metadata: ImageMetadata)
        case text(attributes: TextAttributes)
    }
    
    var inspectorState: InspectorState = .closed
    var isTextViewFirstResponder: Bool = false
    
    private(set) var textAttributes = TextAttributes()
    
    //MARK: - Init
    
    public init() {}
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
