//
//  BoldItalicAndOtherInspectorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 05.06.2025..
//

import SwiftUI

struct BoldItalicAndOtherInspectorView: View {
    
    @Bindable var attributes: TextAttributes
    var onAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    
    private struct StyleToggle: Identifiable, Hashable {
        
        var id: TextAttributes.TextStyleOptions { option }
        let icon: String
        let option: TextAttributes.TextStyleOptions
    }
    
    private let toggles: [StyleToggle] = [
        .init(icon: "bold", option: .bold),
        .init(icon: "italic", option: .italic),
        .init(icon: "underline", option: .underline),
        .init(icon: "strikethrough", option: .strikethrough)
    ]
    
    //MARK: - Body
    
    var body: some View {
        
        let styles = attributes.styleOptions
        
        HStack(spacing: 0) {
            ForEach(toggles) { current in
                let index = toggles.firstIndex(of: current)!
                let isOn = styles.contains(current.option)
                let leftOn = index > 0 && styles.contains(toggles[index - 1].option)
                let rightOn = index < toggles.count - 1 && styles.contains(toggles[index + 1].option)
                
                let appearance = ToggleAppearance(
                    isOn: isOn,
                    roundLeft: index == 0 || !leftOn,
                    roundRight: index == toggles.count - 1 || !rightOn
                )
                
                CustomToggleButton(
                    icon: current.icon,
                    appearance: appearance,
                    action: {
                        var newStyles = attributes.styleOptions
                        if isOn {
                            newStyles.remove(current.option)
                        } else {
                            newStyles.insert(current.option)
                        }
                        attributes.styleOptions = newStyles
                        onAttributesChanged?(attributes, false)
                    }
                )
#if targetEnvironment(macCatalyst)
                .contentShape(Rectangle())
                .onTapGesture {
                    var newStyles = attributes.styleOptions
                    if isOn {
                        newStyles.remove(current.option)
                    } else {
                        newStyles.insert(current.option)
                    }
                    attributes.styleOptions = newStyles
                    onAttributesChanged?(attributes, false)
                }
#endif
            }
        }
        .frame(height: 34)
        .tint(.black)
    }
}

//MARK: - Helpers

fileprivate struct ToggleAppearance: Equatable {
    var isOn: Bool
    var roundLeft: Bool
    var roundRight: Bool
}

fileprivate struct AnimatableToggleModifier: AnimatableModifier {
    
    var isOnProgress: Double
    var leftCornerProgress: Double
    var rightCornerProgress: Double
    
    /// @see https://stackoverflow.com/questions/69952539/how-can-i-animate-changes-to-a-bezierpath-defined-custom-cornerradius-with-swift
    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(isOnProgress, AnimatablePair(leftCornerProgress, rightCornerProgress))
        }
        set {
            isOnProgress = newValue.first
            leftCornerProgress = newValue.second.first
            rightCornerProgress = newValue.second.second
        }
    }
    
    func body(content: Content) -> some View {
        
        let backgroundOpacity = isOnProgress
        let textColor = isOnProgress > 0.5 ? Color.white : Color.black
        let leftRadius = leftCornerProgress * 8
        let rightRadius = rightCornerProgress * 8
        
        content
            .foregroundColor(textColor)
            .padding(.horizontal)
            .frame(height: 34)
            .background(
                GeometryReader { geometry in
                    Path { path in
                        
                        let rect = geometry.frame(in: .local)
                        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
                        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
                        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
                        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
                        
                        path.move(to: CGPoint(x: topLeft.x + leftRadius, y: topLeft.y))
                        path.addLine(to: CGPoint(x: topRight.x - rightRadius, y: topRight.y))
                        
                        if rightRadius > 0 {
                            path.addArc(center: CGPoint(x: topRight.x - rightRadius, y: topRight.y + rightRadius),
                                        radius: rightRadius, startAngle: Angle(radians: -Double.pi/2),
                                        endAngle: Angle(radians: 0), clockwise: false)
                        }
                        
                        path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - rightRadius))
                        
                        if rightRadius > 0 {
                            path.addArc(center: CGPoint(x: bottomRight.x - rightRadius, y: bottomRight.y - rightRadius),
                                        radius: rightRadius, startAngle: Angle(radians: 0),
                                        endAngle: Angle(radians: Double.pi/2), clockwise: false)
                        }
                        
                        path.addLine(to: CGPoint(x: bottomLeft.x + leftRadius, y: bottomLeft.y))
                        
                        if leftRadius > 0 {
                            path.addArc(center: CGPoint(x: bottomLeft.x + leftRadius, y: bottomLeft.y - leftRadius),
                                        radius: leftRadius, startAngle: Angle(radians: Double.pi/2),
                                        endAngle: Angle(radians: Double.pi), clockwise: false)
                        }
                        
                        path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + leftRadius))
                        
                        if leftRadius > 0 {
                            path.addArc(center: CGPoint(x: topLeft.x + leftRadius, y: topLeft.y + leftRadius),
                                        radius: leftRadius, startAngle: Angle(radians: Double.pi),
                                        endAngle: Angle(radians: -Double.pi/2), clockwise: false)
                        }
                        
                        path.closeSubpath()
                    }
                    .fill(Color.accentColor.opacity(backgroundOpacity))
                }
            )
    }
}

fileprivate struct CustomToggleButton: View {
    
    let icon: String
    let appearance: ToggleAppearance
    let action: () -> Void
    
#if targetEnvironment(macCatalyst)
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: icon)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .modifier(AnimatableToggleModifier(
                isOnProgress: appearance.isOn ? 1.0 : 0.0,
                leftCornerProgress: appearance.roundLeft ? 1.0 : 0.0,
                rightCornerProgress: appearance.roundRight ? 1.0 : 0.0
            ))
            .animation(.easeInOut(duration: 0.15), value: appearance)
    }
#else
    var body: some View {
        Image(systemName: icon)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .modifier(AnimatableToggleModifier(
                isOnProgress: appearance.isOn ? 1.0 : 0.0,
                leftCornerProgress: appearance.roundLeft ? 1.0 : 0.0,
                rightCornerProgress: appearance.roundRight ? 1.0 : 0.0
            ))
            .animation(.easeInOut(duration: 0.15), value: appearance)
    }
#endif
}

