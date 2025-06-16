//
//  RichTextViewRepresentable.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

public struct RichTextViewRepresentable: UIViewRepresentable {

    public let interactor: RichTextViewInteractor
    
    public init(interactor: RichTextViewInteractor) {
        self.interactor = interactor
    }
    
    public func makeUIView(context: Context) -> RichTextView {
        print("RichTextViewRepresentable: making new editor!")
        let view = RichTextView(interactor: interactor)
        return view
    }

    public func updateUIView(_ uiView: RichTextView, context: Context) {
        // No update logic needed yet
    }
}
