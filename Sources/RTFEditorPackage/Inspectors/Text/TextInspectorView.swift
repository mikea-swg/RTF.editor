//
//  TextInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI
import PhotosUI

public struct TextInspectorView: View {

    @Bindable public var attributes: TextAttributes
    @Binding public var contentHeight: CGFloat
    public var onAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    public var onInsertImage: ((_ newImage: UIImage) -> Void)?
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var isPhotosPickerPresented: Bool = false
    
#if !targetEnvironment(macCatalyst)
    @State private var isCameraPresented: Bool = false
    @State private var cameraImage: UIImage?
#endif
    
    //MARK: - Body
    
    public var body: some View {
                    
        Form {
            Section("Text Style") {
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
            
            Section("Photos") {
                
                Button {
                    isPhotosPickerPresented.toggle()
                } label: {
                    HStack {
                        Text("Add from Gallery")
                        Spacer()
                        Image(systemName: "photo.stack")
                    }
                }
                .photosPicker(isPresented: $isPhotosPickerPresented,
                              selection: $selectedPickerItem,
                              matching: .images)
                .onChange(of: selectedPickerItem, initial: false) { _, newItem in
                    if let newItem {
                        selectedPickerItemChanged(item: newItem)
                    }
                }

#if !targetEnvironment(macCatalyst)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    
                    Button {
                        isCameraPresented.toggle()
                    } label: {
                        HStack {
                            Text("Take Photo")
                            Spacer()
                            Image(systemName: "camera")
                        }
                    }

                    .sheet(isPresented: $isCameraPresented) {
                        CameraPicker { image in
                            onInsertImage?(image)
                        }
                    }
                }
#endif
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
    
    //MARK: - Actions
    
    private func selectedPickerItemChanged(item: PhotosPickerItem) {
        
#if !targetEnvironment(macCatalyst)
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                onInsertImage?(uiImage)
            }
        }
#endif
    }
}

#Preview {
 
    @Previewable @State var height: CGFloat = 0
    TextInspectorView(attributes: TextAttributes(), contentHeight: $height)
}
