//
//  UIImageView+FacesFill.swift
//  FacesFill
//
//  Created by Beau Nouvelle on 22/7/16.
//  Copyright © 2016 Pear Pi. All rights reserved.
//

import UIKit
import ObjectiveC

public typealias GetCompletionBlock = (_ image: UIImage?) -> Void
public typealias SetCompletionBlock = () -> Void

var SetValidKey: UInt8 = 0
var GetValidKey: UInt8 = 1

@IBDesignable
public extension UIImageView {
    
    private struct AssociatedCustomProperties {
        static var debugFaceAware: Bool = false
        static var setCompletion = "setCompletionKey"
        static var getCompletion = "getCompletionKey"
    }
    
    @IBInspectable
    public var debugFaceAware: Bool {
        set {
            objc_setAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } get {
            guard let debug = objc_getAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware) as? Bool else {
                return false
            }
            
            return debug
        }
    }
    
    @IBInspectable
    public var focusOnFaces: Bool {
        set {
            let image = self.image
            self.image = nil
            set(image: image, focusOnFaces: newValue)
        } get {
            return sublayer() != nil ? true : false
        }
    }
    
    fileprivate var getCompletion: GetCompletionBlock? {
        set {
            objc_setAssociatedObject(self, &AssociatedCustomProperties.getCompletion, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &AssociatedCustomProperties.getCompletion) as? GetCompletionBlock
        }
    }
    
    fileprivate var setCompletion: SetCompletionBlock? {
        set {
            objc_setAssociatedObject(self, &AssociatedCustomProperties.setCompletion, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_COPY_NONATOMIC)
        } get {
            return objc_getAssociatedObject(self, &AssociatedCustomProperties.setCompletion) as? SetCompletionBlock
        }
    }
    
    public func getFaceRecognizeImage(from image: UIImage?, completion: GetCompletionBlock?) {
        self.getCompletion = completion
        setImageAndFocusOnFaces(image: image)
    }
    
    public func set(image: UIImage?, focusOnFaces: Bool, completion: SetCompletionBlock? = nil ) {
        guard focusOnFaces == true else {
            self.removeImageLayer(image: image)
            return
        }
        self.setCompletion = completion
        setImageAndFocusOnFaces(image: image)
    }
    
    private func setImageAndFocusOnFaces(image: UIImage?) {
        DispatchQueue.global(qos: .default).async {
            guard let image = image else {
                return
            }
            
            let cImage = image.ciImage ?? CIImage(cgImage: image.cgImage!)
            
            let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyLow])
            let features = detector!.features(in: cImage)
            
            if features.count > 0 {
                print("found \(features.count) faces")
                let imgSize = CGSize(width: Double(image.cgImage!.width), height: (Double(image.cgImage!.height)))
                self.applyFaceDetection(for: features, size: imgSize, image: image)
            } else {
                print("No faces found")
                self.removeImageLayer(image: image)
            }
        }
    }
    
    private func applyFaceDetection(for features: [AnyObject], size: CGSize, image: UIImage) {
        var rect = features[0].bounds!
        rect.origin.y = size.height - rect.origin.y - rect.size.height
        var rightBorder = Double(rect.origin.x + rect.size.width)
        var bottomBorder = Double(rect.origin.y + rect.size.height)
        
        for feature in features[1..<features.count] {
            var oneRect = feature.bounds!
            oneRect.origin.y = size.height - oneRect.origin.y - oneRect.size.height
            rect.origin.x = min(oneRect.origin.x, rect.origin.x)
            rect.origin.y = min(oneRect.origin.y, rect.origin.y)
            
            rightBorder = max(Double(oneRect.origin.x + oneRect.size.width), Double(rightBorder))
            bottomBorder = max(Double(oneRect.origin.y + oneRect.size.height), Double(bottomBorder))
        }
        
        rect.size.width = CGFloat(rightBorder) - rect.origin.x
        rect.size.height = CGFloat(bottomBorder) - rect.origin.y
        
        var center = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
        var offset = CGPoint.zero
        var finalSize = size
        
        if size.width / size.height > bounds.size.width / bounds.size.height {
            finalSize.height = self.bounds.size.height
            finalSize.width = size.width/size.height * finalSize.height
            center.x = finalSize.width / size.width * center.x
            center.y = finalSize.width / size.width * center.y
            
            offset.x = center.x - self.bounds.size.width * 0.5
            if (offset.x < 0) {
                offset.x = 0
            } else if (offset.x + self.bounds.size.width > finalSize.width) {
                offset.x = finalSize.width - self.bounds.size.width
            }
            offset.x = -offset.x
        } else {
            finalSize.width = self.bounds.size.width
            finalSize.height = size.height / size.width * finalSize.width
            center.x = finalSize.width / size.width * center.x
            center.y = finalSize.width / size.width * center.y
            
            offset.y = center.y - self.bounds.size.height * CGFloat(1-0.618)
            if offset.y < 0 {
                offset.y = 0
            } else if offset.y + self.bounds.size.height > finalSize.height {
                finalSize.height = self.bounds.size.height
                offset.y = finalSize.height
            }
            offset.y = -offset.y
        }
        
        var newImage: UIImage
        if self.debugFaceAware {
            // Draw rectangles around detected faces
            let rawImage = UIImage(cgImage: image.cgImage!)
            UIGraphicsBeginImageContext(size)
            rawImage.draw(at: CGPoint.zero)
            
            let context = UIGraphicsGetCurrentContext()
            context!.setStrokeColor(UIColor.red.cgColor)
            context!.setLineWidth(3)
            
            for feature in features[0..<features.count] {
                var faceViewBounds = feature.bounds!
                faceViewBounds.origin.y = size.height - faceViewBounds.origin.y - faceViewBounds.size.height
                
                context!.addRect(faceViewBounds)
                context!.drawPath(using: .stroke)
            }
            
            newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        } else {
            newImage = image
        }

        DispatchQueue.main.sync {
            if let getCompletion = getCompletion {
                let rect = CGRect(x: offset.x, y: offset.y, width: finalSize.width, height: finalSize.height)
                guard let croppedImage = cropToBounds(image: newImage, rect: rect) else { return }
                
                getCompletion(croppedImage)
            } else {
                self.image = newImage
                
                let layer = self.imageLayer()
                layer.contents = newImage.cgImage
                layer.frame = CGRect(x: offset.x, y: offset.y, width: finalSize.width, height: finalSize.height)
                
                setCompletion?()
            }
        }
    }
    
    private func imageLayer() -> CALayer {
        if let layer = sublayer() {
            return layer
        }
        
        let subLayer = CALayer()
        subLayer.name = "AspectFillFaceAware"
        subLayer.actions = ["contents":NSNull(), "bounds":NSNull(), "position":NSNull()]
        layer.addSublayer(subLayer)
        return subLayer
    }
    
    private func removeImageLayer(image: UIImage?) {
        DispatchQueue.main.async {
            // avoid redundant layer when focus on faces for the image of cell specified in UITableView
            if let getCompletion = self.getCompletion {
                getCompletion(image)
            } else {
                self.imageLayer().removeFromSuperlayer()
                self.image = image
                self.setCompletion?()
            }
        }
    }
    
    private func sublayer() -> CALayer? {
        if let sublayers = layer.sublayers {
            for layer in sublayers {
                if layer.name == "AspectFillFaceAware" {
                    return layer
                }
            }
        }
        return nil
    }
    
    private func cropToBounds(image: UIImage, rect: CGRect) -> UIImage? {
        
        guard let cgImage = image.cgImage else { return nil }
        let contextImage = UIImage(cgImage: cgImage)
        let contextSize: CGSize = contextImage.size

        var posX: CGFloat = 0
        var posY: CGFloat = 0
        var cgwidth: CGFloat = CGFloat(rect.width)
        var cgheight: CGFloat = CGFloat(rect.height)

        // See what size is longer and create the center off of that
        if contextSize.width > contextSize.height {
            cgwidth = contextSize.height
            cgheight = contextSize.height
        } else {
            cgwidth = contextSize.width
            cgheight = contextSize.width
        }
        
        if rect.origin.x != 0 {
            let shift = ceil(rect.origin.x * cgwidth / rect.width)
            posX = (cgwidth + shift) / 2
        }
        if rect.origin.y != 0 {
            let shift = ceil(rect.origin.y * cgheight / rect.height)
            posY = (cgheight + shift) / 2
        }

        let rect: CGRect = CGRect(x: posX, y: posY, width: cgwidth, height: cgheight)
        
        // Create bitmap image from context using the rect
        guard let contextCgImage = contextImage.cgImage,
            let imageRef: CGImage = contextCgImage.cropping(to: rect) else { return nil }
        
        // Create a new image based on the imageRef and rotate back to the original orientation
        let image = UIImage.init(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        let resultWidth: CGFloat = rect.height * self.bounds.width / self.bounds.height
        let resultRect: CGRect = CGRect.init(x: (rect.width - resultWidth) / 2,
                                             y: 0,
                                             width: resultWidth,
                                             height: rect.height)
        
        // Create bitmap image from context using the rect
        guard let contextResultCgImage = image.cgImage,
            let imageResultRef: CGImage = contextResultCgImage.cropping(to: resultRect) else { return nil }
        
        // Create a new image based on the imageRef and rotate back to the original orientation
        let resultImage = UIImage.init(cgImage: imageResultRef, scale: image.scale, orientation: image.imageOrientation)
        
        return resultImage
    }
    
}
