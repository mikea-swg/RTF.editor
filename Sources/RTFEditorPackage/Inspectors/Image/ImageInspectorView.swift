//
//  ImageResizeView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 23.05.2025..
//

import SwiftUI

struct ImageInspectorView: View {
    
    @Bindable var metadata: ImageMetadata
    
    var onMetadataChanged: ((_ metadata: ImageMetadata) -> Void)?
    var onDelete: ((_ metadata: ImageMetadata) -> Void)?
    
    private enum Segment: Int {
        case size
        case style
        case transform
    }
    
    @State private var selectedSegment: Segment = .size
    @State private var isFirstContentHeightSet: Bool = true
    
    //MARK: - Body
    
    var body: some View {

        Form {
            Picker("Resize Mode", selection: $selectedSegment) {
                Text("Size").tag(Segment.size)
                Text("Style").tag(Segment.style)
                Text("Transform").tag(Segment.transform)
            }
            .pickerStyle(SegmentedPickerStyle())
   
            switch selectedSegment {
            case .size:
                sizeControls()
            case .style:
                styleControls()
            case .transform:
                transformOptions()
            }
            
            Section {
                resetOptions()
            }
        }
#if targetEnvironment(macCatalyst)
        .scrollContentBackground(.hidden)
#endif
    }
    
    @ViewBuilder
    private func resetOptions() -> some View {
        
        HStack() {
                        
            switch selectedSegment {
            case .size:
                Button("Reset Size") {
                    metadata.resetSize()
                    metadataChanged()
                }
                .buttonStyle(.borderless)
            case .style:
                Button("Reset Style") {
                    metadata.resetStyle()
                    metadataChanged()
                }
                .buttonStyle(.borderless)
            case .transform:
                Button("Reset Transform") {
                    metadata.resetTransform()
                    metadataChanged()
                }
                .buttonStyle(.borderless)
            }
            
            Spacer()

            Button {
                onDelete?(metadata)
            } label: {
                Image(systemName: "trash")
                    .tint(.red)
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button("Reset All") {
                metadata.resetAll()
                metadataChanged()
            }
            .buttonStyle(.borderless)
        }
    }
    
    @ViewBuilder
    private func sizeControls() -> some View {
        
        Section {
            StepperWithText(text: "Width", value: $metadata.width, range: 1...(max(metadata.maxSize.width, 2000))) {
                if metadata.lockAspectRatio {
                    metadata.height = metadata.width / metadata.originalAspectRatio
                }
                metadataChanged()
            }
            
            StepperWithText(text: "Height", value: $metadata.height, range: 1...(max(metadata.maxSize.height, 2000))) {
                if metadata.lockAspectRatio {
                    metadata.width = metadata.height * metadata.originalAspectRatio
                }
                metadataChanged()
            }
            
            Toggle("Lock Aspect Ratio", isOn: $metadata.lockAspectRatio)
                .onChange(of: metadata.lockAspectRatio) { _, newValue in
                    if newValue {
                        metadata.height = metadata.width / metadata.originalAspectRatio
                        metadataChanged()
                    }
                }
        }
    }
    
    @ViewBuilder
    private func styleControls() -> some View {
        
        Section {
            Toggle(isOn: $metadata.showBorder) {
                Text("Border")
            }
            .onChange(of: metadata.showBorder) { oldValue, newValue in
                metadataChanged()
            }
            
            if metadata.showBorder {
                borderControls()
            }
        }
              
        Section {
            Toggle(isOn: $metadata.showShadow) {
                Text("Shadow")
            }
            .onChange(of: metadata.showShadow) { oldValue, newValue in
                metadataChanged()
            }
            
            if metadata.showShadow {
                shadowControls()
            }
        }
        
        Section {
            opacityControls()
        }
    }
    
    @ViewBuilder
    private func borderControls() -> some View {
        
        colorElement(selection: $metadata.borderColor)

        borderStepperWithText("Width", value: $metadata.borderWidth)
            .onChange(of: metadata.borderWidth) { oldValue, newValue in
                metadataChanged()
            }
    }

    @ViewBuilder
    private func shadowControls() -> some View {
        
        colorElement(selection: $metadata.shadowColor)
        
        StepperWithText(text: "Radius", value: $metadata.shadowRadius, range: 0...15)
            .onChange(of: metadata.shadowRadius) { _, _ in
                metadataChanged()
            }
        
        StepperWithText(text: "X", value: $metadata.shadowOffsetX, range: -20...20)
            .onChange(of: metadata.shadowOffsetX) { _, _ in
                metadataChanged()
            }

        StepperWithText(text: "Y", value: $metadata.shadowOffsetY, range: -20...20)
            .onChange(of: metadata.shadowOffsetY) { _, _ in
                metadataChanged()
            }
    }
    
    
    @ViewBuilder
    private func opacityControls() -> some View {
        
        Text("Opacity")
            .frame(maxWidth: .infinity, alignment: .leading)
        
        HStack {
            Slider(value: $metadata.opacity, in: 0...1.0)
                .onChange(of: metadata.opacity) { _, _ in
                    metadataChanged()
                }
            
            Spacer()
            
            Text("\(Int(metadata.opacity * 100))%")
                .frame(width: 72.0)
                .applyStepperStyleBackground()
        }
    }
        
    @ViewBuilder
    private func transformOptions() -> some View {
        
        Section {
            
            VStack {
                Text("Rotation")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                RotationDial(angle: $metadata.rotation)
                    .frame(width: 135, height: 135)
                    .onChange(of: metadata.rotation) { _, _ in
                        metadataChanged()
                    }
            }
            .padding(.bottom)
            
            Button {
                metadata.isFlippedHorizontal.toggle()
                metadataChanged()
            } label: {
                HStack {
                    Text("Flip horizontal")
                    Spacer()
                    Image(systemName: "arrow.trianglehead.left.and.right.righttriangle.left.righttriangle.right.fill")
                }
            }
            .buttonStyle(.bordered)
            .foregroundStyle(Color(uiColor: .label))
            
            Button {
                metadata.isFlippedVertical.toggle()
                metadataChanged()
            } label: {
                Text("Flip vertical")
                Spacer()
                Image(systemName: "arrow.trianglehead.up.and.down.righttriangle.up.righttriangle.down.fill")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(Color(uiColor: .label))
        }
    }
    
    private func metadataChanged() {
        onMetadataChanged?(metadata)
    }
}

extension ImageInspectorView {
        
    @ViewBuilder
    private func borderStepperWithText(_ text: String,
                                       value: Binding<CGFloat>,
                                       onEditingChanged: (() -> Void)? = nil) -> some View {
        HStack {
            Text(text)
            Spacer()
            Text(("\(value.wrappedValue.formatted())pt"))
                .padding(.horizontal)
                .applyStepperStyleBackground()
        
            BorderStepper(value: value)
                .onChange(of: value.wrappedValue, { oldValue, newValue in
                    onEditingChanged?()
                })
            .fixedSize()
        }
    }
    
    @ViewBuilder
    private func colorElement(selection: Binding<Color>) -> some View {
        
        ColorPickerWithText(color: selection)
            .onChange(of: selection.wrappedValue) { _, _ in
                metadataChanged()
            }
    }
}

#Preview {
    ImageInspectorView(metadata: ImageMetadata(image: UIImage(systemName: "pencil")!,
                                               defaultSize: CGSize(width: 200, height: 400)))
}
