//
//  AprilTagDetector.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import Foundation

class AprilTagDetector: NSObject, VirtualContentController {
    
    var contentNode: SCNNode?
    var sceneView: ARSCNView?
    var session: ARSession?
    
//    let img: UIImage
//    var myImageView: UIImageView
//    var myFrame: CGRect

//    override init() {
//        // Load and april tag
////        self.img = UIImage(named: "AprilTag.png")!
//        // Image view instance to display the image
////        self.myImageView = UIImageView(image: img)
////        self.myFrame = CGRect(x: 0.0,y: 0.0,width: self.myImageView.frame.size.width,
////                              height: self.myImageView.frame.size.height)
////        self.myImageView.frame = myFrame
//    }

    // Detect AprilTag
    
    /// - Tag: ARNodeTracking
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // This class adds AR content only for face anchors.
        guard anchor is ARFaceAnchor else { return nil }
        
        // Load an asset from the app bundle to provide visual content for the anchor.
        contentNode = SCNReferenceNode(named: "coordinateOrigin")
        
        // Provide the node to ARKit for keeping in sync with the face anchor.
        return contentNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard #available(iOS 12.0, *), let _ = anchor as? ARFaceAnchor
            else { return }
//        let orient = UIInterfaceOrientation(rawValue: UIDevice.current.orientation.rawValue)!
//        let viewportSize = sceneView!.bounds.size
//        let transform = sceneView?.session.currentFrame?.displayTransform(for: orient, viewportSize: viewportSize).inverted()
        let finalImage = CIImage(cvImageBuffer: (session?.currentFrame!.capturedImage)!)
        AprilTag.find(UIImage(ciImage: finalImage))
    }
    
    func addAprilTagMarkers() {
        guard #available(iOS 12.0, *), let _ = contentNode else { return }
        
    }
}
