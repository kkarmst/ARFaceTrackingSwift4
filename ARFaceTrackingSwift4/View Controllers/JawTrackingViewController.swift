/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains the main app implementation using Vision.
 */

import UIKit
import ARKit
import AVFoundation


class JawTrackingViewController: UIViewController, AVCaptureDelegate {
    
    // Main view outlet for showing camera content.
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var frameRateLabel: UILabel!
    @IBOutlet var uiView: UIView!
    @IBOutlet weak var tagDataToggleState: UISwitch!
    @IBOutlet weak var framesToggleState: UISwitch!
    @IBOutlet weak var camDataToggleState: UISwitch!
    let avCapture = AVCapture()
    var visp = AprilTag()
    var targetTagIds = [Int32]()
    var tagFamily = "36h11"
    var captureStatus = "RUN"
    var modes:DisplayMode = .distance
    var tagSize = 14.25 //mm
    var frontcam = true
    var img: UIImage!
    var previewLayer:CALayer!
    
    // UDP Connection Variables 
    var broadcastTags: UDPBroadcastConnection!
    var broadcastPoseConnection: UDPBroadcastConnection!
    var broadcastImagesConnection: UDPBroadcastConnection!
    let ipAddress = "192.168.0.14"
    var streamTagData = false
    var streamCamData = false
    var streamFrames = false
    var camIntrinsics:matrix_float3x3 = matrix_float3x3.init()
    var imageIndex:Int = 0             // this is the sequence number in the image stream
    
    // Queue variables
    let aprilTagQueue = DispatchQueue(label: "apriltag", qos: DispatchQoS.userInitiated)
    
    // Timer Variables
    var poseTimer = Timer()
    var imageTimer = Timer()
    var tagFinderTimer = Timer()
    
    struct AprilTagDataSwift {
        var number:Int32 = 0
        var posData = Array(repeating: 0.0, count: 16)
    }
    struct TupletoArray {
        var tuple: (Double, Double, Double, Double, Double, Double,Double, Double, Double, Double, Double, Double,Double, Double, Double, Double)
        var array: [Double] {
            var tmp = self.tuple
            return [Double](UnsafeBufferPointer(start: &tmp.0, count: MemoryLayout.size(ofValue: tmp)))
        }
    }
    
    struct Config {
        
        struct Ports {
            static let broadcast = UInt16(35601)
            static let broadcastImages = UInt16(35602)
            static let broadcastAprilTags = UInt16(7709)
        }
        
    }
    
    // MARK: UIViewController overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        avCapture.delegate = self
//        avCapture.previewLayer.frame = uiView.bounds
//        avCapture.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        //        uiView.layer.addSublayer(avCapture.previewLayer)
        tagDataToggleState.isOn = false
        camDataToggleState.isOn = false
        framesToggleState.isOn = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        avCapture.startCaptureSession()
        self.setupUdpConnections()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avCapture.stopCaptureSession()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - AVCaptureSession
    
    func capture(image: UIImage, intrinsic: matrix_float3x3) {
        let start = Date()
        self.img = image
        self.camIntrinsics = intrinsic
        var params = [
            intrinsic.columns.0.x,
            intrinsic.columns.1.y,
            intrinsic.columns.2.x,
            intrinsic.columns.2.y
        ]
        let vispImg = visp.find(image,targetIds:&targetTagIds, count:Int32(targetTagIds.count), family:tagFamily, intrinsic:&params, tagSize: Int32(tagSize), display:modes)
        let flippedImage = UIImage(cgImage: (vispImg?.cgImage!)!, scale: vispImg!.scale, orientation: .upMirrored)
        
        if (frontcam) {
            imageView.image = flippedImage
        } else {
            imageView.image = vispImg
        }
        
        let end = Date()
        let fps = (1/((end.timeIntervalSince(start))))
        frameRateLabel.text = String(format: "%5.2f FPS", fps)
    }
    
    // MARK: - UIActions
    @IBAction func buttonCameraSwap(_ sender: UIButton) {
        avCapture.switchCameraPosition()
        frontcam.toggle()
        flipAnimation()
    }
    
    @IBAction func tagDataToggleTapped(_ sender: UISwitch) {
        if (tagDataToggleState.isOn) {
            tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitTags), userInfo: nil, repeats: true)
            tagDataToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
            self.streamTagData = true
        } else if (!tagDataToggleState.isOn){
            // stop
            tagDataToggleState.removeTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
            self.streamTagData = false
        }
    }
    
    @IBAction func camDataToggleTapped(_ sender: Any) {
        if (camDataToggleState.isOn) {
            poseTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitPoseData), userInfo: nil, repeats: true)
            camDataToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
            self.streamCamData = true
        } else if (!camDataToggleState.isOn){
            // stop
            camDataToggleState.removeTarget(self, action: #selector(scheduledTimerToTransmitData), for: .valueChanged)
            self.streamCamData = false
        }
    }
    
    
    @IBAction func framesToggleTapped(_ sender: UISwitch) {
        if (framesToggleState.isOn) {
            imageTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitImages), userInfo: nil, repeats: true)
            framesToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
            self.streamFrames = true
        } else if (!framesToggleState.isOn){
            // stop
            framesToggleState.removeTarget(self, action: #selector(scheduledTimerToTransmitData), for: .valueChanged)
            self.streamFrames = false
        }
    }
    
    /// Initializes timers to send data at regular intervals
    @objc func scheduledTimerToTransmitData() {
        print("Checking to see what to transmit")
        poseTimer.invalidate()
        poseTimer = Timer()
        
        if camDataToggleState.isOn {
            poseTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitPoseData), userInfo: nil, repeats: true)
        }
        imageTimer.invalidate()
        imageTimer = Timer()
        
        if framesToggleState.isOn {
            imageTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitImages), userInfo: nil, repeats: true)
        }
        tagFinderTimer.invalidate()
        
        if tagDataToggleState.isOn {
            tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitTags), userInfo: nil, repeats: true)
        }
        
    }
    
    @objc func transmitTags() {
        if (self.streamTagData == true) {
            aprilTagQueue.async {
                self.broadcastTags.sendBroadcast(self.getArTags(vispImage: self.img, timeStamp: Double(Date().timeIntervalSince1970)))
                //                print(self.getArTags(vispImage: self.img, timeStamp: Double(Date().timeIntervalSince1970)))
            }
        }
        
    }
    
    @objc func transmitPoseData() {
        if (self.streamCamData == true) {
            self.broadcastPoseConnection.sendBroadcast(getCameraIntrinsics())
//            print("posedata")
        }
    }
    
    @objc func transmitImages() {
        if (self.streamFrames == true) {
            let intrinsics = getCameraIntrinsics()
            let MTU = 1350
            let image = self.img!
            let imageData = image.jpegData(compressionQuality: 0)
            var bytesSent = 0           // Keeps track of how much of the image has been sent
            var packetIndex = 0         // Packet number - so ROS can recompile the image in order
            let start: [UInt8] = Array("start".utf8)


            while bytesSent < imageData!.count {
                // Construct the range for the packet
                let range = (bytesSent..<min(bytesSent + MTU, imageData!.count))
                var udpPacketPayload = imageData!.subdata(in: range)
                udpPacketPayload.insert(UInt8(imageIndex % (Int(UInt8.max) + 1)), at: 0)
                udpPacketPayload.insert(UInt8(packetIndex), at: 1)

                if bytesSent == 0 {
                    let numPackets = (Float(imageData!.count) / Float(MTU)).rounded(.up)
                    udpPacketPayload.insert(UInt8(numPackets), at: 2)
                    udpPacketPayload.insert(UInt8(intrinsics.count), at: 3)
                    udpPacketPayload.insert(contentsOf: intrinsics, at: 4)
                }
                broadcastImagesConnection.sendBroadcast(udpPacketPayload)
                bytesSent += range.count
                packetIndex += 1
            }
            imageIndex += 1
//            print("stream images")
        }

    }
    
    func flipAnimation() {
        let blurView = UIVisualEffectView(frame: imageView.bounds)
        blurView.effect = UIBlurEffect(style: .light)
        imageView.addSubview(blurView)
        
        UIView.transition(with: imageView, duration: 0.4, options: .transitionFlipFromLeft, animations: nil) { (finished) -> Void in
            blurView.removeFromSuperview()
        }
    }
    
    func setupUdpConnections() {
        let INADDR_BROADCAST = in_addr(s_addr: inet_addr(ipAddress))
        
        broadcastPoseConnection = UDPBroadcastConnection(port: Config.Ports.broadcast, ip: INADDR_BROADCAST) {(port: Int, response: [UInt8]) -> Void in
            print("Received from \(INADDR_BROADCAST):\(port):\n\n\(response)")
        }
        
        broadcastImagesConnection = UDPBroadcastConnection(port: Config.Ports.broadcastImages, ip: INADDR_BROADCAST) {(port: Int, response: [UInt8]) -> Void in
            print("Received from \(INADDR_BROADCAST):\(port):\n\n\(response)")
        }
        
        broadcastTags = UDPBroadcastConnection(port: Config.Ports.broadcastAprilTags, ip: INADDR_BROADCAST) {(port: Int, response: [UInt8]) -> Void in
            print("Received from \(INADDR_BROADCAST):\(port):\n\n\(response)")
        }
    }
    
    func getArTags(vispImage: UIImage, timeStamp: Double) -> String {
        var tagArray: Array<AprilTagDataSwift> = Array()
        let numTags = visp.getNumberOfTags()
        var poseMatrix = "START"
        if numTags > 0 {
            for i in 0...visp.getNumberOfTags()-1 {
                let pose = TupletoArray(tuple: visp.getAt(i).poseData).array
                let number = visp.getAt(i).number
                let tagdata = AprilTagDataSwift(number: number, posData: pose)
                tagArray.append(tagdata)
            }
            
            for i in 0...tagArray.count-1 {
                let pose = tagArray[i].posData
                poseMatrix = poseMatrix + "," + String(format: "TAG,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", tagArray[i].number, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7], pose[8], pose[9], pose[10], pose[11], pose[12], pose[13], pose[14], pose[15], timeStamp)
            }
        }
        return poseMatrix
    }
    
    func getCameraIntrinsics() -> Data {
        let intrinsics = self.camIntrinsics
        let columns = intrinsics.columns
        let res = self.img.size
        let width = res.width
        let height = res.height
        
        return String(format: "%f,%f,%f,%f,%f,%f",  columns.0.x, columns.1.y, columns.2.x, columns.2.y, width, height).data(using: .utf8)!
    }
    
    // Get pose data (transformation matrix, time)
    func getCameraCoordinates() -> String {
        let camera = sceneView.session.currentFrame?.camera
        let cameraTransform = camera?.transform
        let relativeTime = sceneView.session.currentFrame?.timestamp
        let scene = SCNMatrix4(cameraTransform!)
        
        let fullMatrix = String(format: "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", scene.m11, scene.m12, scene.m13, scene.m14, scene.m21, scene.m22, scene.m23, scene.m24, scene.m31, scene.m32, scene.m33, scene.m34, scene.m41, scene.m42, scene.m43, scene.m44, relativeTime!)
        
        return fullMatrix
    }
    
    //    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    //
    ////        let pixelBuffer = frame.capturedImage
    ////        CVPixelBufferLockBaseAddress(pixelBuffer,CVPixelBufferLockFlags(rawValue: 0))
    ////        let address = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    ////        let bufferWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer,0)
    ////        let bufferHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    ////        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    //    }
    
    
}
