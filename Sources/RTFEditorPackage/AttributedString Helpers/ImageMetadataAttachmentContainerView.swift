//
//  ImageMetadataAttachmentContainerView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 29.05.2025..
//

import UIKit

class ImageMetadataAttachmentContainerView: UIView {
    
    private let imageView: UIImageView
    private let tapButton: UIButton
    private let metadata: ImageMetadata
    private var onTap: ((_ metadata: ImageMetadata) -> Void)?
    
    init(image: UIImage, metadata: ImageMetadata, onTap: ((_ metadata: ImageMetadata) -> Void)?) {
        
        self.imageView = UIImageView(image: image)
        self.tapButton = UIButton(type: .custom)
        self.metadata = metadata
        self.onTap = onTap
        
        super.init(frame: .zero)
        
        clipsToBounds = false
        layer.masksToBounds = false
        backgroundColor = .clear

        setupImageView()
        updateImageView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Temporarily remove transform
        let currentTransform = imageView.transform
        imageView.transform = .identity
        
        // Set frame without transform
        imageView.frame = CGRect(x: bounds.size.width / 2.0 - metadata.width / 2.0,
                                y: bounds.size.height / 2.0 - metadata.height / 2.0,
                                width: metadata.width,
                                height: metadata.height)
        
        // Reapply transform because otherwise it looks wrong. Don't use .center + .bounds combination!
        imageView.transform = currentTransform
        
        tapButton.frame = imageView.bounds
    }
    
    //MARK: - Setup
    
    private func setupImageView() {
                
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true // Enable interaction for imageView
        addSubview(imageView)

#if targetEnvironment(macCatalyst)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        imageView.addGestureRecognizer(tapGesture)
#else
        tapButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        imageView.addSubview(tapButton)
#endif
    }
    
    @objc private func handleTap() {
        onTap?(metadata)
    }
    
    private func updateImageView() {
        
        imageView.alpha = metadata.opacity
        
        // Transform: Flip and rotate
        var transform = CGAffineTransform.identity
        if metadata.isFlippedHorizontal {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        if metadata.isFlippedVertical {
            transform = transform.scaledBy(x: 1, y: -1)
        }
        if metadata.rotation != 0 {
            let radians = CGFloat(metadata.rotation * .pi / 180)
            transform = transform.rotated(by: radians)
        }
        imageView.transform = transform
        
        // Border
        if metadata.showBorder {
            imageView.layer.borderWidth = metadata.borderWidth
            imageView.layer.borderColor = UIColor(metadata.borderColor).cgColor
        } else {
            imageView.layer.borderWidth = 0
            imageView.layer.borderColor = nil
        }
        
        // Shadow
        if metadata.showShadow {
            imageView.layer.shadowColor = UIColor(metadata.shadowColor).cgColor
            imageView.layer.shadowOpacity = Float(metadata.opacity)
            imageView.layer.shadowRadius = metadata.shadowRadius
            imageView.layer.shadowOffset = CGSize(width: metadata.shadowOffsetX, height: metadata.shadowOffsetY)
        } else {
            imageView.layer.shadowColor = nil
            imageView.layer.shadowOpacity = 0
            imageView.layer.shadowRadius = 0
            imageView.layer.shadowOffset = .zero
        }
    }
}
