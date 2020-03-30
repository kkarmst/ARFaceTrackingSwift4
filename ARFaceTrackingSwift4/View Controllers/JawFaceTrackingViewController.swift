//
//  JawFaceTrackingViewController.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2020-02-24.
//  Copyright © 2020 Kieran Armstrong. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

import Foundation

class JawFaceTrackingViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet var inFrame: UIImageView!
    @IBOutlet var outFrame: UIImageView!
    
    
    @IBOutlet var tagDataToggleState: UISwitch!
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentBuffer: CVPixelBuffer?
    var apriltagdetector = AprilTag()
    var targetTagIds = [Int32]()
    var tagFamily = "36h11"
    var captureStatus = "RUN"
    var aprilDisplayMode:DisplayMode = .orientation
    var tagSize = 5.0 //mm
    var isProcessingFrame = false
    
    // Timer Variables
    var poseTimer = Timer()
    var imageTimer = Timer()
    var tagFinderTimer = Timer()
    
    // Queue variables
    let trackingQueue = DispatchQueue(label: "apriltag", qos: DispatchQoS.userInitiated)
    
    // Display content properties
//    var contentControllers: [VirtualContentType: VirtualContentController] = [:]
//
//    var selectedVirtualContent: VirtualContentType! {
//        didSet {
//            guard oldValue != nil, oldValue != selectedVirtualContent
//                else { return }
//
//            // Remove existing content when switching types.
//            contentControllers[oldValue]?.contentNode?.removeFromParentNode()
//
//            // If there's an anchor already (switching content), get the content controller to place initial content.
//            // Otherwise, the content controller will place it in `renderer(_:didAdd:for:)`.
//            if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
//                let newContent = selectedContentController.renderer(sceneView, nodeFor: anchor) {
//                node.addChildNode(newContent)
//            }
//        }
//    }
//    var selectedContentController: VirtualContentController {
//        if let controller = contentControllers[selectedVirtualContent] {
//            return controller
//        } else {
//            let controller = selectedVirtualContent.makeController()
//            contentControllers[selectedVirtualContent] = controller
//            return controller
//        }
//    }
    
    
    struct AprilTagDataSwift {
        var number:Int32 = 0
        var posData = Array(repeating: 0.0, count: 16)
    }

    struct TupletoArray {
        var tuple: (Double, Double, Double, Double, Double, Double,Double, Double, Double, Double, Double, Double,Double, Double, Double, Double)
        var array: [Double] {
            var tmp = self.tuple
            return [Double](UnsafeBufferPointer(start: &tmp.0, count: 16))
        }
    }
    
    // Virtual Content Controller
    var currentFaceAnchor: ARFaceAnchor?
  
    // MARK: - View controller lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.showsStatistics = true
        
        tagDataToggleState.isOn = false
//        selectedVirtualContent = VirtualContentType(rawValue: 1)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        initARFaceTracking()
        initWorldTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        // Retain the image buffer for Vision processing.
        self.currentBuffer = frame.capturedImage
   
    }
    
    // MARK: - Actions
    
    @IBAction func tagDataToggleTapped(_ sender: UISwitch) {
        if (tagDataToggleState.isOn) {
            tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitTags), userInfo: nil, repeats: true)
            tagDataToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)

        } else if (!tagDataToggleState.isOn){
            // stop
            tagDataToggleState.removeTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)

        }
    }
    
    // MARK: - Timers
    // Initializes timers to send data at regular intervals
       @objc func scheduledTimerToTransmitData() {
           print("Checking to see what to transmit")
           tagFinderTimer.invalidate()
           
           if tagDataToggleState.isOn {
               tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitTags), userInfo: nil, repeats: true)
           }
           
       }
       
       @objc func transmitTags() {
        if isProcessingFrame {
            return
        }
        isProcessingFrame = true
        let imagePixelBuffer = sceneView.session.currentFrame!.capturedImage
        
        CVPixelBufferLockBaseAddress(imagePixelBuffer, [])
//
        let image = imageFromCVPixelBuffer(pixelBuffer: imagePixelBuffer)
        let rotatedImage = imageRotatedByDegrees(oldImage: image!, deg: 90)
//        rotatedImage.transform = CGAffineTransform(scaleX: -1, y: 1); //Flipped

//        let flippedImage = rotatedImage.trans

        CVPixelBufferUnlockBaseAddress(imagePixelBuffer,[])
//
        trackingQueue.async {
            self.getArTags(rotatedImage: rotatedImage)
            self.isProcessingFrame = false
        }
       }
    
    
    // MARK: -  ARFaceTrackingSetup
    func initARFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func initWorldTracking() {
        guard ARWorldTrackingConfiguration.isSupported else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        configuration.isAutoFocusEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    
    // MARK: - AR Session Handling
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    }
    
   func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
//            self.initARFaceTracking()
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
        return true
    }
    
    // MARK: - Error handling
    private func displayErrorMessage(title: String, message: String) {
        
    }
    
    // MARK: - AprilTag Helpers
    /// Get video frames.
    func getVideoFrames() -> (UIImage, Double) {
        let cameraFrame = sceneView.session.currentFrame
        let stampedTime = cameraFrame?.timestamp
        
        // Convert ARFrame to a UIImage
        let pixelBuffer = cameraFrame?.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        return (uiImage, stampedTime!)
    }
    
    /// Get pose data (transformation matrix, time) and send to ROS.
    func getCameraCoordinates() -> String {
        let camera = sceneView.session.currentFrame?.camera
        let cameraTransform = camera?.transform
        let relativeTime = sceneView.session.currentFrame?.timestamp
        let scene = SCNMatrix4(cameraTransform!)
        
        let fullMatrix = String(format: "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44, relativeTime!)
        
        return fullMatrix
    }
    
    // Finds all april tags in the frame
    func getArTags(rotatedImage: UIImage) -> Array<AprilTagDataSwift> {
        var tagArray: Array<AprilTagDataSwift> = Array()
        let intrinsics = sceneView.session.currentFrame?.camera.intrinsics.columns
        let pixelBuffer = sceneView.session.currentFrame?.capturedImage
        let camIntrinsics =  sceneView.session.currentFrame?.camera.intrinsics
//        let transMatrix = self.apriltagdetector.transformMatrix(from: pixelBuffer, withIntrinsics: camIntrinsics!)
        
        DispatchQueue.main.async {
//            self.inFrame.image = rotatedImage
//            self.sceneView.scene.background.contents = pixelBuffer
            
//            let outImg = self.apriltagdetector.estimatePose(fromCVBuffer: pixelBuffer, intrinsics!.1.y, intrinsics!.0.x, intrinsics!.2.y, intrinsics!.2.x)
            let outImg = self.apriltagdetector.estimatePose(from: rotatedImage, intrinsics!.1.y, intrinsics!.0.x, intrinsics!.2.y, intrinsics!.2.x)
//            let rotatedOutImage = self.imageRotatedByDegrees(oldImage: outImg!, deg: 90)
            self.outFrame.image = outImg
//            self.sceneView.scene.background.contents = rotatedOutImage

        }
        

        
        return tagArray
    }
        
    /// Get the camera intrinsics to send to ROS
    func getCameraIntrinsics() -> Data {
        let camera = sceneView.session.currentFrame?.camera
        let intrinsics = camera?.intrinsics
        let columns = intrinsics?.columns
        let res = camera?.imageResolution
        let width = res?.width
        let height = res?.height
        
        return String(format: "%f,%f,%f,%f,%f,%f,%f", columns!.0.x, columns!.1.y, columns!.2.x, columns!.2.y, columns!.2.z, width!, height!).data(using: .utf8)!
        }
    
    // MARK: - Image Processing Helpers
    
    /// Rotates an image clockwise
    func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        //Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: -1.0, y: -1.0)
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func imageMirroredVertically(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        //Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: -1.0, y: -1.0)
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func imageFromCVPixelBuffer(pixelBuffer :CVPixelBuffer) -> UIImage? {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let pixelBufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelBufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageRect:CGRect = CGRect(x: 0, y: 0, width: pixelBufferWidth, height: pixelBufferHeight)
        let ciContext = CIContext.init()
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: imageRect) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}

// Convert device orientation to image orientation for use by Vision analysis.
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}

extension JawFaceTrackingViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor

        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
//        if node.childNodes.isEmpty, let contentNode = selectedContentController.renderer(renderer, nodeFor: faceAnchor) {
//            node.addChildNode(contentNode)
//        }

        // Get the currernt frame for AprilTag detection
//        selectedContentController.session = sceneView.session
//        selectedContentController.sceneView = sceneView

//        print(currentFaceAnchor?.rightEyeTransform.columns.3 ?? 0)
    }

    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//        guard anchor == currentFaceAnchor,
//            let contentNode = selectedContentController.contentNode,
//            contentNode.parent == node
//            else { return }
//
        
//        selectedContentController.session = sceneView.session
//        selectedContentController.sceneView = sceneView
//        selectedContentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
    
    

}

