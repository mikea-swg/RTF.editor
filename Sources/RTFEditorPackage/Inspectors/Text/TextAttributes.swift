//
//  TextAttributes.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import Foundation
import Observation
import UIKit
import SwiftUI

@Observable
public final class TextAttributes {
    
    let fontFamilies: [String]
    
    struct FontStyle: Hashable {
        
        let fullName: String
        let displayName: String
        
        init(fullName: String) {
            self.fullName = fullName
            self.displayName = Self.displayName(for: fullName)
        }
        
        private static func displayName(for fontName: String) -> String {
            let descriptor = UIFontDescriptor(name: fontName, size: 16)
            return descriptor.object(forKey: .face) as? String ?? fontName
        }
    }
    
    private(set) var fontStyles: [FontStyle] = []
    
    var selectedFontFamily: String = "Arial"
    var selectedFontStyle: FontStyle = FontStyle(fullName: "ArialMT")
    var fontSize: Double = 17
    
    struct TextStyleOptions: OptionSet, Hashable {
        let rawValue: Int
        
        static let bold          = TextStyleOptions(rawValue: 1 << 0)
        static let italic        = TextStyleOptions(rawValue: 1 << 1)
        static let underline     = TextStyleOptions(rawValue: 1 << 2)
        static let strikethrough = TextStyleOptions(rawValue: 1 << 3)
    }
    
    var styleOptions: TextStyleOptions = []
    
    var color: Color = .black
    var textAlignment: NSTextAlignment = .left
    var textListMarkerFormat: NSTextList.MarkerFormat?
    
    //MARK: - Initialization
    
    public init(attributes: [NSAttributedString.Key: Any]? = nil) {
        
        fontFamilies = UIFont.familyNames.sorted().filter { familyName in
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            
            let hasBold = fontNames.contains { fontName in
                let font = UIFont(name: fontName, size: 12) ?? UIFont.systemFont(ofSize: 12)
                return font.fontDescriptor.symbolicTraits.contains(.traitBold)
            }
            
            let hasItalic = fontNames.contains { fontName in
                let font = UIFont(name: fontName, size: 12) ?? UIFont.systemFont(ofSize: 12)
                return font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            }
            
            return hasBold && hasItalic
        }
        
        selectInitialFontFamily()
        
        if let attributes {
            updateWith(attributes: attributes)
        }
    }
    
    func updateWith(attributes: [NSAttributedString.Key: Any]) {
        
        styleOptions = []
        
        // Font
        if let font = attributes[.font] as? UIFont {
            self.fontSize = font.pointSize
            self.selectedFontStyle = FontStyle(fullName: font.fontName)
            self.selectedFontFamily = font.familyName
            
            let traits = font.fontDescriptor.symbolicTraits
            if traits.contains(.traitBold) {
                styleOptions.insert(.bold)
            }
            if traits.contains(.traitItalic) {
                styleOptions.insert(.italic)
            }
        }
        
        // Underline
        if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
            styleOptions.insert(.underline)
        }
        
        // Strikethrough
        if let strikethrough = attributes[.strikethroughStyle] as? Int, strikethrough != 0 {
            styleOptions.insert(.strikethrough)
        }
        
        // Text color
        if let uiColor = attributes[.foregroundColor] as? UIColor {
            self.color = Color(uiColor)
        } else {
            self.color = .black
        }
        
        // Alignment (comes from paragraph style)
        if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
            self.textAlignment = paragraph.alignment

            if paragraph.textLists.count == 1 {
                self.textListMarkerFormat = paragraph.textLists[0].markerFormat
            } else {
                self.textListMarkerFormat = nil
            }
        } else {
            self.textAlignment = .left
            self.textListMarkerFormat = nil
        }
        
        // Optional: Recalculate fontStyles for selected family
        if fontFamilies.contains(selectedFontFamily) {
            fontStyles = UIFont.fontNames(forFamilyName: selectedFontFamily).map(FontStyle.init)
        }
    }
    
    func toAttributedStringKeyDict() -> [NSAttributedString.Key: Any] {
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Construct font descriptor from selected family and style
        var descriptor = UIFontDescriptor(name: selectedFontStyle.fullName, size: fontSize)
        
        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
        
        if styleOptions.contains(.bold) {
            symbolicTraits.insert(.traitBold)
        }
        if styleOptions.contains(.italic) {
            symbolicTraits.insert(.traitItalic)
        }
        
        if let updatedDescriptor = descriptor.withSymbolicTraits(symbolicTraits) {
            descriptor = updatedDescriptor
        }
        
        let font = UIFont(descriptor: descriptor, size: fontSize)
        attributes[.font] = font
        
        // Foreground color
        attributes[.foregroundColor] = UIColor(color)
        
        // Underline
        attributes[.underlineStyle] = styleOptions.contains(.underline) ? NSUnderlineStyle.single.rawValue : 0
        
        // Strikethrough
        attributes[.strikethroughStyle] = styleOptions.contains(.strikethrough) ? NSUnderlineStyle.single.rawValue : 0
        
        // Paragraph style (for alignment)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        
        // Lists
        if let textListMarkerFormat {
            paragraphStyle.textLists = [NSTextList(markerFormat: textListMarkerFormat, options: 0)]
        } else {
            paragraphStyle.textLists = []
        }
        
        attributes[.paragraphStyle] = paragraphStyle
        
        return attributes
    }
}

extension NSTextList.MarkerFormat {
    
    public static let decimalDot: NSTextList.MarkerFormat = NSTextList.MarkerFormat(rawValue: "{decimal}.")
}

extension TextAttributes {

    func selectInitialFontFamily() {
        
        if let arial = fontFamilies.first(where: { $0.lowercased().contains("helvetica") }) {
            selectedFontFamily = arial
            loadFontStyles(for: arial)
        } else if let first = fontFamilies.first {
            selectedFontFamily = first
            loadFontStyles(for: first)
        }
    }
    
    func loadFontStyles(for family: String) {
        let styles = UIFont.fontNames(forFamilyName: family)
            .sorted()
            .map({
                FontStyle(fullName: $0)
            })
        
        fontStyles = styles
        
        if let regular = styles.first(where: { $0.displayName.lowercased().contains("regular")}) {
            selectedFontStyle = regular
        } else if let first = styles.first {
            selectedFontStyle = first
        } else {
            fatalError("This font is missing a style")
        }
    }
}
