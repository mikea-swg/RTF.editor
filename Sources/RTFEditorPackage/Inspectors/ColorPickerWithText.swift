//
//  ColorPickerWithText.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

struct ColorPickerWithText: View {
    
    var text: String = String(localized: "Color")
    @Binding var color: Color
    
    var body: some View {
        HStack {
            if text.isEmpty == false {
                Text(text)
                    .fixedSize()
                Spacer()
            }
            ColorPicker("", selection: $color)
                .frame(width: 40)
        }
    }
}

#Preview {
    ColorPickerWithText(color: .constant(.black))
}
