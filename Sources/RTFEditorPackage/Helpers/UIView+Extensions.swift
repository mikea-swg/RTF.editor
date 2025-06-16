//
//  File.swift
//  RTFEditorPackage
//
//  Created by Josip Bernat on 16.06.2025..
//

import Foundation
import UIKit

extension UIView {
    /// Pins the view's edges to its superview's edges with optional insets.
    func pinEdgesToSuperviewEdges(withInsets insets: UIEdgeInsets = .zero) {
        guard let superview = self.superview else {
            print("Warning: No superview found for \(self).")
            return
        }
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -insets.bottom),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -insets.right)
        ])
    }
    
    func pinEdgesToSuperviewSafeArea(withInsets insets: UIEdgeInsets = .zero) {
        guard let superview = self.superview else {
            print("Warning: No superview found for \(self).")
            return
        }
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor, constant: insets.left),
            bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor, constant: -insets.bottom),
            trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor, constant: -insets.right)
        ])
    }
}
