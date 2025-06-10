//
//  ImageResizeViewModel.swift
//  RTFEditor
//
//  Created by Josip Bernat on 27.05.2025..
//

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
public final class ImageMetadata: Codable {
    
    struct DefaultValue {
        static let lockAspectRatio: Bool = true
        
        static let rotation: Double = 0
        static let isFlippedHorizontal = false
        static let isFlippedVertical = false
        static let opacity: Double = 1.0
        
        static let showBorder: Bool = false
        static let borderMinWidth: CGFloat = 0.25
        static let borderMaxWidth: CGFloat = 10.0
        static let borderWidth: CGFloat = 1.0
        static let borderColorStorage: CodableColor = CodableColor(.black)
     
        static let showShadow: Bool = false
        static let shadowRadius: CGFloat = 1
        static let shadowOffsetX: CGFloat = 0.0
        static let shadowOffsetY: CGFloat = 0.0
        static let shadowColorStorage: CodableColor = CodableColor(.black.opacity(0.3))
    }
    
    let id: UUID
    let originalSize: CGSize
    let originalAspectRatio: CGFloat
    
    // Size
    var width: CGFloat
    var height: CGFloat
    var lockAspectRatio = DefaultValue.lockAspectRatio
    
    // Style - Border
    var showBorder: Bool = DefaultValue.showBorder
    var borderWidth: CGFloat = DefaultValue.borderWidth
    private var borderColorStorage: CodableColor = DefaultValue.borderColorStorage
    
    // Style - Shadow
    var showShadow: Bool = DefaultValue.showShadow
    var shadowRadius: CGFloat = DefaultValue.shadowRadius
    var shadowOffsetX: CGFloat = DefaultValue.shadowOffsetX
    var shadowOffsetY: CGFloat = DefaultValue.shadowOffsetY
    private var shadowColorStorage: CodableColor = DefaultValue.shadowColorStorage
    
    // Transform
    var rotation: Double = DefaultValue.rotation
    var isFlippedHorizontal = DefaultValue.isFlippedHorizontal
    var isFlippedVertical = DefaultValue.isFlippedVertical
    
    // Style - Opacity
    var opacity: Double = DefaultValue.opacity
    
    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    var borderColor: Color {
        get { borderColorStorage.color }
        set { borderColorStorage = CodableColor(newValue) }
    }
    
    var shadowColor: Color {
        get { shadowColorStorage.color }
        set { shadowColorStorage = CodableColor(newValue) }
    }
        
    //MARK: - Initialization
    
    init(image: UIImage) {
        
        self.id = UUID()
        self.width = image.size.width
        self.height = image.size.height
        
        self.originalSize = image.size
        self.originalAspectRatio = image.size.width / image.size.height
    }
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        
        case id
        case _width                 = "width"
        case _height                = "height"
        case _lockAspectRatio       = "lock_aspect_ratio"
        case originalSize           = "original_size"
        case originalAspectRatio    = "original_aspect_ratio"
        case _rotation              = "rotation"
        case _isFlippedHorizontal   = "is_flipped_horizontal"
        case _isFlippedVertical     = "is_flipped_vertical"
        case _opacity               = "opacity"
        case _showBorder            = "show_border"
        case _borderWidth           = "border_width"
        case _borderColorStorage    = "border_color"
        case _showShadow            = "show_shadow"
        case _shadowRadius          = "shadow_radius"
        case _shadowOffsetX         = "shadow_offset_x"
        case _shadowOffsetY         = "shadow_offset_y"
        case _shadowColorStorage    = "shadow_color"
    }
    
    //MARK: - Resize
    
    func resizeImage(maxWidth: CGFloat) {
        width = maxWidth
        if lockAspectRatio {
            height = maxWidth / originalAspectRatio
        }
    }
    
    //MARK: - Reset
    
    func resetSize() {
        
        width = originalSize.width
        height = originalSize.height
        lockAspectRatio = DefaultValue.lockAspectRatio
    }
    
    func resetStyle() {
        
        showBorder = DefaultValue.showBorder
        borderWidth = DefaultValue.borderWidth
        borderColorStorage = DefaultValue.borderColorStorage
        
        showShadow = DefaultValue.showShadow
        shadowRadius = DefaultValue.shadowRadius
        shadowOffsetX = DefaultValue.shadowOffsetX
        shadowOffsetY = DefaultValue.shadowOffsetY
        shadowColorStorage = DefaultValue.shadowColorStorage
        
        opacity = DefaultValue.opacity
    }
    
    func resetTransform() {
        
        rotation = DefaultValue.rotation
        isFlippedHorizontal = DefaultValue.isFlippedHorizontal
        isFlippedVertical = DefaultValue.isFlippedVertical
    }
    
    func resetAll() {
        resetSize()
        resetStyle()
        resetTransform()
    }
}

extension ImageMetadata {
    
    func jsonDict() -> [String: Any] {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return dict ?? [:]
        } catch {
            fatalError("An error occurred while serializing ImageResizeViewModel: \(error)")
        }
    }
    
    static func fromJsonDict(_ dict: [String: Any]) -> ImageMetadata? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let result = try? JSONDecoder().decode(ImageMetadata.self, from: data) else {
            return nil
        }
        return result
    }
}

extension Data {
    
    func asImageMetadata() -> ImageMetadata? {
        do {
            let result = try JSONDecoder().decode(ImageMetadata.self, from: self)
            return result
        } catch {
            print("Error parsing JSON: \(error)")
            return nil
        }
    }
}

struct CodableColor: Codable {
    
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        // You can customize this if you use UIColor/NSColor
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(alpha)
    }
}
