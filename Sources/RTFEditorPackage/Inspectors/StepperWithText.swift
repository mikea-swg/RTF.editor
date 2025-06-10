//
//  StepperWithText.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

struct StepperWithText<T: IntegerNumber & Strideable>: View {
    
    let text: String
    @Binding var value: T
    let range: ClosedRange<T>
    var onEditingChanged: (() -> Void)?
    
    var body: some View {
        HStack {
            
            if text.isEmpty == false {
                Text(text)
                    .fixedSize()
                Spacer()
            }
            
            Text(("\(value.toInt())pt"))
                .padding(.horizontal)
                .applyStepperStyleBackground()
        
            Stepper("", value: $value, in: range)
                .onChange(of: value, { oldValue, newValue in
                    onEditingChanged?()
                })
            .labelsHidden()
            .fixedSize()
        }
    }
}

extension Color {
    
    static let inspectorElementBackground = Color(red: 238 / 255.0, green: 238 / 255.0, blue: 239 / 255.0)
}

extension View {
    
    func applyStepperStyleBackground() -> some View {
        
        self.frame(height: 32.0)
            .background(Color.inspectorElementBackground)
            .applyDefaultRtfInspectorCornerRadius()
    }
    
    var defaultRtfInspectorCornerRadius: CGFloat {
        8.0
    }
    
    func applyDefaultRtfInspectorCornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: defaultRtfInspectorCornerRadius))
    }
}

#Preview {
    @Previewable @State var test: CGFloat = 0
    StepperWithText(text: "Test", value: $test, range: 0...10)
}
