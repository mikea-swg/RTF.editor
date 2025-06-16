//
//  TextAttributesPopoverViewController.swift
//  RTFEditorPackage
//
//  Created by Josip Bernat on 13.06.2025..
//

import UIKit
import SwiftUI

public final class TextAttributesPopoverViewController: UIViewController {
    
    @Bindable public var attributes: TextAttributes
    @Binding public var contentHeight: CGFloat
    public var onAttributesChanged: ((_ attributes: TextAttributes, _ insertNewList: Bool) -> Void)?
    
    public init(attributes: TextAttributes,
                contentHeight: Binding<CGFloat>,
                onAttributesChanged: ((_ attributes: TextAttributes, _: Bool) -> Void)? = nil) {
        
        /// We must set values this way otherwise we are getting errors.
        self._attributes = Bindable(wrappedValue: attributes)
        self._contentHeight = contentHeight
        self.onAttributesChanged = onAttributesChanged
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - View Lifecycle
    
    private let topPadding: CGFloat = 20
    private let bottomPadding: CGFloat = 20
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Text", comment: "")
        
        self.view.backgroundColor = .systemGroupedBackground
        
        // Create an intermediate binding that adds padding and navigation bar height
        let adjustedContentHeight = Binding<CGFloat>(
            get: { 0 }, // SwiftUI will set this, we don't need to read it
            set: { [weak self] newContentHeight in
                guard let self = self else { return }
                
                // Calculate total height including padding and navigation bar
                let totalPadding = self.topPadding + self.bottomPadding
                let totalHeight = newContentHeight + totalPadding
                
                // Update the original binding with the adjusted height
                self.contentHeight = totalHeight
            }
        )
        
        let swiftUIView = TextInspectorView(attributes: attributes,
                                            contentHeight: adjustedContentHeight,
                                            onAttributesChanged: onAttributesChanged)
        
        let hostingViewController = UIHostingController(rootView: swiftUIView)
        addChild(hostingViewController)
        self.view.addSubview(hostingViewController.view)
        hostingViewController.view.pinEdgesToSuperviewSafeArea(withInsets: UIEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0))
        hostingViewController.didMove(toParent: self)        
    }
}
