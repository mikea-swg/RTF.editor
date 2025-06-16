//
//  RichTextConstants.swift
//  RTFEditor
//
//  Created by Josip Bernat on 03.06.2025..
//

import Foundation
import UniformTypeIdentifiers

public struct RichTextConstants {
    
    static let zeroWidthSpace = "\u{200B}"
    public static let rtfdslExtension = ".rtfdsl"
}

extension UTType {
    static let rtfdsl = UTType(exportedAs: "com.seeworkgrow.rtf-editor.rtfdsl")
}
