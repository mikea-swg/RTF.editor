//
//  TextAlignmentInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

struct TextAlignmentInspectorView: View {
    @Binding var alignment: NSTextAlignment
    
    var body: some View {
        HStack(spacing: 0) {
            alignmentToggle(icon: "text.alignleft", value: .left)
            alignmentToggle(icon: "text.aligncenter", value: .center)
            alignmentToggle(icon: "text.alignright", value: .right)
            alignmentToggle(icon: "text.justify", value: .justified)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
    }
    
#if targetEnvironment(macCatalyst)
    
    @ViewBuilder
    private func alignmentToggle(icon: String, value: NSTextAlignment) -> some View {
        HStack {
            Spacer()
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundColor(alignment == value ? .white : .primary)
            Spacer()
        }
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8.0)
                .fill(alignment == value ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            alignment = value
        }
    }
#else
    @ViewBuilder
    private func alignmentToggle(icon: String, value: NSTextAlignment) -> some View {
        Toggle(isOn: Binding(
            get: { alignment == value },
            set: { isOn in if isOn { alignment = value } })
        ) {
            Image(systemName: icon)
                .frame(maxWidth: .infinity) // <-- Equal width
        }
        .toggleStyle(TextAlignmentInspectorToggleStyle())
        .labelsHidden()
    }
#endif
}
#Preview {
    @Previewable @State var alignment = NSTextAlignment.left
    TextAlignmentInspectorView(alignment: $alignment)
}


fileprivate struct TextAlignmentInspectorToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            configuration.label
                .imageScale(.medium)
                .foregroundColor(configuration.isOn ? .white : .black)
                .frame(height: 34)
                .padding(.horizontal)
                .background(
                    configuration.isOn ? Color.accentColor : nil// Color.inspectorElementBackground
                )
                .clipShape(RoundedRectangle(cornerRadius: 8.0))
        }
        .buttonStyle(.plain)
    }
}
