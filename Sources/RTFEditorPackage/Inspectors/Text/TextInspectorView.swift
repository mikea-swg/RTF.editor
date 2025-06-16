//
//  TextInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

public struct TextInspectorView: View {

    @Bindable public var attributes: TextAttributes
    @Binding public var contentHeight: CGFloat
    public var onAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    //MARK: - Body
    
    public var body: some View {
                    
        Form {
            Section {
                FontInspectorView(attributes: attributes, onAttributesChanged: onAttributesChanged)
                
                TextAlignmentInspectorView(alignment: $attributes.textAlignment)
                    .onChange(of: attributes.textAlignment) { oldValue, newValue in
                        onAttributesChanged?(attributes, false)
                    }
                
                TextListInspectorView(markerFormat: $attributes.textListMarkerFormat,
                                      onValueChanged: { markerFormat, insertNewList in
                    attributes.textListMarkerFormat = markerFormat
                    onAttributesChanged?(attributes, insertNewList)
                })
            }
        }
#if targetEnvironment(macCatalyst)
        .scrollContentBackground(.hidden)
#endif
        
#if !targetEnvironment(macCatalyst)
        .onScrollGeometryChange(for: [Double].self, of: { geometry in
            [
                geometry.contentSize.height,
            ]
        }, action: { _, newValue in
            let contentHeight = newValue[0]
            if contentHeight != 0 {
                self.contentHeight = contentHeight
            }
        })
//        .scrollDisabled(true)
#endif
    }
}

#Preview {
 
    @Previewable @State var height: CGFloat = 0
    TextInspectorView(attributes: TextAttributes(), contentHeight: $height)
}
