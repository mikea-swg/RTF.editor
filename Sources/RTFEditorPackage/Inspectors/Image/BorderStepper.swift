//
//  CustomStepper.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

struct BorderStepper: View {
    
    let steps: [CGFloat] = {
        let fine = stride(from: ImageMetadata.DefaultValue.borderMinWidth, through: 1.0, by: 0.25).map { CGFloat($0) }
        let coarse = stride(from: 2.0, through: ImageMetadata.DefaultValue.borderMaxWidth, by: 1.0).map { CGFloat($0) }
        return fine + coarse
    }()
    
    @Binding var value: CGFloat
    
    var body: some View {
        Stepper("") {
            increment()
        } onDecrement: {
            decrement()
        }
        .labelsHidden()
    }
    
    private func increment() {
        guard let currentIndex = steps.firstIndex(of: value),
              currentIndex < steps.count - 1 else { return }
        value = steps[currentIndex + 1]
    }
    
    private func decrement() {
        guard let currentIndex = steps.firstIndex(of: value),
              currentIndex > 0 else { return }
        value = steps[currentIndex - 1]
    }
}

#Preview(body: {
    @Previewable @State var value: CGFloat = 0.25
    BorderStepper(value: $value)
})
