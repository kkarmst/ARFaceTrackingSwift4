//
//  FaceTrackingViewController.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-30.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import ReplayKit
import Foundation

class FaceTrackingViewController: UIViewController, ARSessionDelegate, AVAudioRecorderDelegate {
    
     let recorder = RPScreenRecorder.shared()
    
    // MARK: Outlets

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sessionToggle: UISwitch!
    @IBOutlet weak var ipTextField: UITextField!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var sessionLabel: UILabel!
    
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
//    var session: ARSession {
//        return sceneView.session
//    }
    
    var isCapturing = false {
           didSet {
   
           }
       }
    
    var captureMode = CaptureMode.stream {
        didSet {
            if captureMode == .record {
                 if sessionToggle.isOn { sessionToggle.isOn = false }
            }
            refreshInfo()
            ini.set(captureMode == .record, forKey: "mode")
        }
    }
    
    // Streaming mode properties
    var host = "192.168.86.24" {
           didSet {
               ini.set(host, forKey: "host")
           }
       }
       var port = 2020 {
           didSet {
               ini.set(port, forKey: "port")
           }
       }
    
    var inStream: InputStream!
    var outStream: OutputStream!
    var connect: Bool = true
    
    // Record mode Properites
    var fps = 30.0 {
        didSet {
            fps = min(max(fps, 1.0), 60.0)
            ini.set(fps, forKey: "fps")
        }
    }
    var fpsTimer: Timer!
    var captureData: [CaptureData]!
    var currentCaptureFrame = 0
    var folderPath : URL!
    
    // Queue Properties
    private let saveQueue = DispatchQueue.init(label: "kieranwarmstrong.ARFaceTrackingSwift4")
    private let dispatchGroup = DispatchGroup()
    
    // MARK: ACTIONS
    
    @IBAction func connectButtonClick(_ sender: Any) {
        if(ipTextField.text != "" && connectButton.title(for: .normal) == "Enable") {
//                  ipTextField.endEditing(true)
                  connect = true
                  startCapture()

                  connectButton.setTitle("Disable", for: .normal)
                  connectButton.backgroundColor = UIColor.systemRed
              }
              else if (connectButton.title(for: .normal) == "Disable" ) {
                  connectButton.setTitle("Enable", for: .normal)
                  connectButton.backgroundColor = UIColor.systemGreen
                  connect = false
                  stopCapture()
              }
              else {
                  let alert = UIAlertController(title: "Message", message: "IP was either incorrect or this not valid", preferredStyle: UIAlertController.Style.alert)
                  alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                  self.present(alert,animated: true, completion:nil)
              }
    }
    

    @IBAction func sessionRecordToggle(_ sender: Any) {
        if (connect == true) {
            connect = false
            sessionToggle.isOn = true
            
        } else if (connect == false) {
            connect = true
            sessionToggle.isOn = false
        }
        
        if (sessionToggle.isOn == true) {
            recorder.startRecording(withMicrophoneEnabled: true) { (error) in
                if let error = error{
                    print(error)
                }
            }
        }
        if (sessionToggle.isOn == false) {
            recorder.stopRecording { (previewVC, error) in
                if let previewVC = previewVC {
                    previewVC.previewControllerDelegate = self
                    self.present(previewVC, animated: true, completion: nil)
                }
                if let error = error{
                    print(error)
                }
            }
        }
    }
    
    
    
    var currentFaceAnchor: ARFaceAnchor?
    
    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))

        //Uncomment the line below if you want the tap not not interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false

        view.addGestureRecognizer(tap)

        if let lastHost = ini.string(forKey: "host") {
                  host = lastHost
              }
              let lastPort = ini.integer(forKey: "port")
              if lastPort != 0 {
                  port = lastPort
              }
              let lastFps = ini.double(forKey: "fps")
              if lastFps != 0 {
                  fps = lastFps
              }
              let lastMode = ini.bool(forKey: "mode")
              if lastMode {
                  captureMode = .record
              }else{
                  captureMode = .stream
              }
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
//        self.ipTextField.delegate = self
        ipTextField.text = host
        UIApplication.shared.isIdleTimerDisabled = true
        
        selectedVirtualContent = VirtualContentType(rawValue: 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initARFaceTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
         stopCapture()
//         DispatchQueue.main.async {
//             self.initARFaceTracking()
//         }
     }
     func sessionWasInterrupted(_ session: ARSession) {
         return
     }
     func sessionInterruptionEnded(_ session: ARSession) {
         DispatchQueue.main.async {
             self.initARFaceTracking()
         }
     }
     func session(_ session: ARSession, didUpdate frame: ARFrame) {
         // When capture mode is stream, execute streaming here
         if captureMode == .stream && isCapturing && connect == false {
            streamData(connect: false)
         }
        if captureMode == .stream && isCapturing && connect {
           streamData(connect: true)
        }
     }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        self.host = ipTextField.text!
        view.endEditing(true)
    }
    
    func refreshInfo() {
        switch captureMode{
        case .record:
            sessionLabel.text = "Stream"
        case .stream:
            sessionLabel.text = "Stream"
        }
    }
    /// - Tag: ARFaceTrackingSetup
    func initARFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    /// - Tag: ARTracking
    func initARWorldTracking() {
        let configuration = ARWorldTrackingConfiguration()
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
    
    // MARK: - Streaming
      func startCapture() { // Where capture button pressed, streaming or recording

        refreshInfo()

        switch captureMode {

        case .stream:
            // Stream Mode : Create socket, connect to server
            if outStream != nil {
                outStream.close()
            }
            
            var out: OutputStream?
            Stream.getStreamsToHost(withName: host, port: port, inputStream: nil, outputStream: &out)
            outStream = out!
            outStream.open()
            isCapturing = true  // This will let didUpdate delegate to stream data

        case .record:
            // Record Mode : Clean record data, create save folder, use timer to record for stable fps
            captureData = []
            currentCaptureFrame = 0
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            folderPath = documentPath.appendingPathComponent(folderName())
            try? FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: true, attributes: nil)
            isCapturing = true
            fpsTimer = Timer.scheduledTimer(withTimeInterval: 1/fps, repeats: true, block: {(timer) -> Void in
                self.recordData()
            })

        }
    }
    
    func stopCapture() { // Stop Capture Process
          
          isCapturing = false
          switch captureMode {
          case .stream:
              // Stream Mode : Send "z" to server to tell that I'm stop streaming
              let dataStr = "z"
              let dataBuffer = dataStr.data(using: .utf8)!
              _ = dataBuffer.withUnsafeBytes { self.outStream.write($0, maxLength: dataBuffer.count) }
              outStream.close()
          case .record:
              // Record Mode : Turn off timer, convert capture data to string and save into documentary
              fpsTimer.invalidate()
              let fileName = folderPath.appendingPathComponent("faceData.txt")
              let data = captureData.map{ $0.str }.joined(separator: "\n")
              try? data.write(to: fileName, atomically: false, encoding: String.Encoding.utf8)
              dispatchGroup.wait() // Wait until last image saved
          }
      }
          
    func streamData(connect: Bool) {
          
          if outStream.streamStatus == .error {
              stopCapture()
              return
          }
          
        if (connect) {
            self.sessionToggle.isOn = false
        } else if (!connect) {
           self.sessionToggle.isOn = true
        }
        
          guard let data = getFrameData() else {return}
          
          dispatchGroup.enter()
          saveQueue.async{
              autoreleasepool {
                if (connect) {
                  let dataStr = "a" // Let server know where bytes received finished
                    let dataBuffer = dataStr.data(using: .utf8)!
                    if self.outStream.streamStatus == .open {
                        _ = dataBuffer.withUnsafeBytes { self.outStream.write($0, maxLength: dataBuffer.count) }
                    }
                } else {
                    let dataStr = data.str // Let server know where bytes received finished
                    let dataBuffer = dataStr.data(using: .utf8)!
                    if self.outStream.streamStatus == .open {
                        _ = dataBuffer.withUnsafeBytes { self.outStream.write($0, maxLength: dataBuffer.count) }
                    }
                }

              }
          }
      }
      
    func recordData() { // Every frame's process in record mode
           guard let data = getFrameData() else {return}
           captureData.append(data)
           
           let snap = sceneView.session.currentFrame!.capturedImage
           let num = currentCaptureFrame // Image sequence's filename
           
           dispatchGroup.enter()
           saveQueue.async{
               autoreleasepool { // Prevent JPEG conversion memory leak
                   let writePath = self.folderPath.appendingPathComponent( String(format: "%04d", num)+".jpg" )
                   ((try? UIImage(pixelBuffer: snap).jpegData(compressionQuality: 0.85)?.write(to: writePath)) as ()??)
                   self.dispatchGroup.leave()
               }
           }
           currentCaptureFrame += 1
       }
    
    func getFrameData() -> CaptureData? { // Organize arkit's data
        let arFrame = sceneView.session.currentFrame!
        guard let anchor = arFrame.anchors[0] as? ARFaceAnchor else {return nil}
        let vertices = anchor.geometry.vertices
        let data = CaptureData(vertices: vertices)
        return data
    }
    
    //MARK: - UTILITY
    func folderName() -> String {
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd_HHmmss"
        let date = Date()
        let folderStr = dateFormatter.string(from: date)
        return folderStr
    }
    
    func popRecordSetting() {
        let alert = UIAlertController(title: "Record Setting", message: "Set frames per second.", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "\(self.fps)"
            textField.keyboardType = .decimalPad
        })
        
        let okAction = UIAlertAction(title: "Accept", style: .default, handler: { (action) -> Void in
            self.fps = Double(alert.textFields![0].text!)!
            self.refreshInfo()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {(action) -> Void in})
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func popStreamSetting() {
        let alert = UIAlertController(title: "Stream Setting", message: "Set stream server IP address.", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = self.host
            textField.keyboardType = .decimalPad
        })
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "\(self.port)"
            textField.keyboardType = .decimalPad
        })
        
        let okAction = UIAlertAction(title: "Accept", style: .default, handler: { (action) -> Void in
            if alert.textFields![0].text != "" {
                self.host = alert.textFields![0].text!
            }
            if alert.textFields![1].text != "" {
                self.port = Int(alert.textFields![1].text!)!
            }
            self.refreshInfo()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {(action) -> Void in})
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension FaceTrackingViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let contentType = VirtualContentType(rawValue: item.tag)
            else { fatalError("unexpected virtual content tag") }
        selectedVirtualContent = contentType
    }
}

extension FaceTrackingViewController: ARSCNViewDelegate {

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

extension FaceTrackingViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

}

//added by andrew
extension FaceTrackingViewController:RPPreviewViewControllerDelegate{
    func previewControllerDidFinish(_ previewController:RPPreviewViewController) {
        dismiss(animated: true, completion: nil)
    }
}
