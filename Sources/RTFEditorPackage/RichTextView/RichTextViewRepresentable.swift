//
//  RichTextViewRepresentable.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import SwiftUI

public struct RichTextViewRepresentable: UIViewRepresentable {

    var interactor: RichTextViewInteractor
    
    public func makeUIView(context: Context) -> RichTextView {
        let view = RichTextView()
        view.interactor = interactor
        return view
    }

    public func updateUIView(_ uiView: RichTextView, context: Context) {
        // No update logic needed yet
    }
}
