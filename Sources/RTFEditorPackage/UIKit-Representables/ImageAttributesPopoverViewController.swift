//
//  ImageAttributesPopoverViewController.swift
//  RTFEditorPackage
//
//  Created by Josip Bernat on 16.06.2025..
//

import UIKit
import SwiftUI

public final class ImageAttributesPopoverViewController: UIViewController {

    @Bindable public var metadata: ImageMetadata
    public var onMedatadaChanged: ((_ metadata: ImageMetadata) -> Void)?
    public var onDelete: ((_ metadata: ImageMetadata) -> Void)?
    
    public init(metadata: ImageMetadata,
                onMedatadaChanged: ((_ metadata: ImageMetadata) -> Void)?,
                onDelete: ((_ metadata: ImageMetadata) -> Void)?) {
        
        /// We must set values this way otherwise we are getting errors.
        self._metadata = Bindable(wrappedValue: metadata)
        self.onMedatadaChanged = onMedatadaChanged
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - View Lifecycle
    
    private let topPadding: CGFloat = 0
    private let bottomPadding: CGFloat = 20
    
    public override func viewDidLoad() {
        super.viewDidLoad()
                
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.view.backgroundColor = .systemGroupedBackground
        
        let swiftUIView = ImageInspectorView(metadata: metadata,
                                             onMetadataChanged: onMedatadaChanged,
                                             onDelete: onDelete)
        
        let hostingViewController = UIHostingController(rootView: swiftUIView)
        addChild(hostingViewController)
        self.view.addSubview(hostingViewController.view)
        hostingViewController.view.pinEdgesToSuperviewSafeArea(withInsets: UIEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0))
        hostingViewController.didMove(toParent: self)
    }

}
