//
//  DynamicFontInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

struct FontInspectorView: View {
    
    @Bindable var attributes: TextAttributes
    var onAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
        
    //MARK: - Body
    
    var body: some View {
        
#if targetEnvironment(macCatalyst)
        Picker("Font", selection: $attributes.selectedFontFamily) {
            ForEach(attributes.fontFamilies, id: \.self) { family in
                Text(family)
                    .tag(family)
            }
        }
        .onChange(of: attributes.selectedFontFamily) { oldValue, newValue in
            attributes.loadFontStyles(for: newValue)
            toggleOnAttributesChanged()
        }
        
        Picker("Style", selection: $attributes.selectedFontStyle) {
            ForEach(attributes.fontStyles, id: \.self) { style in
                Text(style.displayName)
                    .tag(style)
            }
        }
        .onChange(of: attributes.selectedFontStyle) { oldValue, newValue in
            toggleOnAttributesChanged()
        }
#else
        NavigationLink {
            fontPickerView(initialFamily: attributes.selectedFontFamily)
        } label: {
            
            HStack {
                Text("Font")
                Spacer()
                Text(attributes.selectedFontFamily)
                    .font(.custom(attributes.selectedFontFamily, size: UIFont.labelFontSize))
            }
        }
#endif
        
        BoldItalicAndOtherInspectorView(attributes: attributes,
                                        onAttributesChanged: onAttributesChanged)
        
        StepperWithText(text: "Size", value: $attributes.fontSize, range: 1...100)
            .onChange(of: attributes.fontSize) { oldValue, newValue in
                toggleOnAttributesChanged()
            }
        
        ColorPickerWithText(text: "Color", color: $attributes.color)
            .onChange(of: attributes.color) { oldValue, newValue in
                toggleOnAttributesChanged()
            }
    }

    @ViewBuilder
    private func fontPickerView(initialFamily: String) -> some View {
        
        ScrollViewReader { proxy in
            List {
                ForEach(attributes.fontFamilies, id: \.self) { family in
                    HStack {
                        Text(family)
                            .font(.custom(family, size: UIFont.labelFontSize))
                        
                        Spacer()
                        
                        if family == attributes.selectedFontFamily {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        attributes.selectedFontFamily = family
                    }
                    .id(family)
                }
            }
            .navigationTitle("Fonts")
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(attributes.selectedFontFamily, anchor: .center)
                }
            }
            .onDisappear {
                
                if initialFamily != attributes.selectedFontFamily {
                    attributes.loadFontStyles(for: initialFamily)
                    toggleOnAttributesChanged()
                }
            }
        }
        .navigationTitle("Fonts")
    }
    
    private func toggleOnAttributesChanged() {
        onAttributesChanged?(attributes, false)
    }
}

#Preview {
    FontInspectorView(attributes: TextAttributes())
}

