//
//  TextListInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 02.06.2025..
//

import SwiftUI
import Foundation

struct TextListInspectorView: View {
  
    @Binding var markerFormat: NSTextList.MarkerFormat?
    var onValueChanged: ((NSTextList.MarkerFormat?, Bool) -> Void)?
    
    var body: some View {
        HStack(spacing: 0.0) {
            formatButton(.circle, image: "list.bullet")
            Divider().frame(width: 1)
            formatButton(.hyphen, image: "list.dash")
            Divider().frame(width: 1)
            formatButton(.decimalDot, image: "list.number")
        }
        .frame(height: 34)
        .tint(.black)
        .applyDefaultRtfInspectorCornerRadius()
    }

    @ViewBuilder
    private func formatButton(_ format: NSTextList.MarkerFormat, image: String) -> some View {
        let isSelected = markerFormat == format

        Button(action: {
            let previous = markerFormat
            markerFormat = isSelected ? nil : format
            if markerFormat != previous {
                onValueChanged?(markerFormat, markerFormat != nil)
            }
        }) {
            Image(systemName: image)
                .imageScale(.medium)
                .foregroundColor(isSelected ? .white : .black)
                .frame(height: 34)
                .padding(.horizontal)
                .background(isSelected ? Color.accentColor : Color.inspectorElementBackground)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    
    @Previewable @State var format: NSTextList.MarkerFormat?
    TextListInspectorView(markerFormat: $format)
}
