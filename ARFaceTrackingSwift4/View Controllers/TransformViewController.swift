/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import ARKit
import SceneKit
import Foundation

class TransformViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate {
       
    // MARK: Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: Properties
    
    private let ini = UserDefaults.standard  // Store user setting

    // Display content properties
    var contentControllers: [VirtualContentType: VirtualContentController] = [:]
    
    var selectedVirtualContent: VirtualContentType! {
        didSet {
            guard oldValue != nil, oldValue != selectedVirtualContent
                else { return }
            
            // Remove existing content when switching types.
            contentControllers[oldValue]?.contentNode?.removeFromParentNode()
            
            // If there's an anchor already (switching content), get the content controller to place initial content.
            // Otherwise, the content controller will place it in `renderer(_:didAdd:for:)`.
            if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
                let newContent = selectedContentController.renderer(sceneView, nodeFor: anchor) {
                node.addChildNode(newContent)
            }
        }
    }
    var selectedContentController: VirtualContentController {
        if let controller = contentControllers[selectedVirtualContent] {
            return controller
        } else {
            let controller = selectedVirtualContent.makeController()
            contentControllers[selectedVirtualContent] = controller
            return controller
        }
    }
    
    // Capture properites
    var session: ARSession {
        return sceneView.session
    }

    // Record mode Properites
    var fps = 30.0 {
        didSet {
            fps = min(max(fps, 1.0), 60.0)
            ini.set(fps, forKey: "fps")
        }
    }
    var fpsTimer: Timer!
    
    // MARK: ACTIONS
    
    var currentFaceAnchor: ARFaceAnchor?
    
    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true

        // Set the initial face content.
        selectedVirtualContent = VirtualContentType(rawValue: 0)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Set the initial face content.
        initARFaceTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
       }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
         DispatchQueue.main.async {
             self.initARFaceTracking()
         }
     }
     func sessionWasInterrupted(_ session: ARSession) {
         return
     }
     func sessionInterruptionEnded(_ session: ARSession) {
         DispatchQueue.main.async {
             self.initARFaceTracking()
         }
     }

    // MARK: - ARFaceTrackingSetup
    func initARFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.initARFaceTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - ARSceneViewDelegate
       func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            currentFaceAnchor = faceAnchor

            // If this is the first time with this anchor, get the controller to create content.
            // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
            if node.childNodes.isEmpty, let contentNode = selectedContentController.renderer(renderer, nodeFor: faceAnchor) {
                node.addChildNode(contentNode)
            }
            
            // Get the currernt frame for AprilTag detection
            selectedContentController.session = sceneView.session
            selectedContentController.sceneView = sceneView

    //        print(currentFaceAnchor?.rightEyeTransform.columns.3 ?? 0)
        }

        /// - Tag: ARFaceGeometryUpdate
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard anchor == currentFaceAnchor,
                let contentNode = selectedContentController.contentNode,
                contentNode.parent == node
                else { return }
            
            selectedContentController.session = sceneView.session
            selectedContentController.sceneView = sceneView
            selectedContentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        }

}

extension TransformViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let contentType = VirtualContentType(rawValue: 0)
            else { fatalError("unexpected virtual content tag") }
        selectedVirtualContent = contentType
    }
}



