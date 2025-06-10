//
//  RotationDial.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import SwiftUI

struct RotationDial: View {
    
    @Binding var angle: Double
    @State private var startAngle: Double = 0.0
    @State private var initialDragAngle: Double?
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let trackWidth: CGFloat = 15
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // Arc knob length (as a fraction of the full circle)
            let arcLength: CGFloat = 0.1  // Adjust this to make the arc longer/shorter
            
            ZStack {
                // Track
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: trackWidth)
                
                // Arc Knob
                Circle()
                    .trim(from: 0, to: arcLength)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .rotationEffect(.degrees(angle - 90 - (arcLength * 360 / 2.0))) // Center the arc on the angle
                    .position(center)
                
                // Angle label
                Text("\(Int(angle))°")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundColor(.orange)
                    .position(center)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let vector = CGVector(
                            dx: value.location.x - center.x,
                            dy: value.location.y - center.y
                        )
                        var dragAngle = atan2(vector.dy, vector.dx) * 180 / .pi
                        if dragAngle < 0 { dragAngle += 359 }
                        
                        if initialDragAngle == nil {
                            initialDragAngle = dragAngle
                            startAngle = angle
                        }
                        
                        let delta = dragAngle - (initialDragAngle ?? dragAngle)
                        var newAngle = (startAngle + delta).truncatingRemainder(dividingBy: 360)
                        if newAngle < 0 { newAngle += 359 }
                        
                        let roundedAngle = newAngle.rounded()
                        if angle != roundedAngle {
                            angle = roundedAngle
                        }
                    }
                    .onEnded { _ in
                        initialDragAngle = nil
                        startAngle = angle
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    RotationDial(angle: .constant(0.0))
}
