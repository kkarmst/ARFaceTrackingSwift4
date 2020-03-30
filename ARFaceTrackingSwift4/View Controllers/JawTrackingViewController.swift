/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains the main app implementation using Vision.
 */

import UIKit
import ARKit
import AVFoundation
import Vision
import SwiftyJSON

class JawTrackingViewController: UIViewController,AVCaptureDelegate {
    
    // Main view outlet for showing camera content.
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var frameRateLabel: UILabel!
    @IBOutlet var uiView: UIView!
    @IBOutlet weak var tagDataToggleState: UISwitch!
    @IBOutlet var inFrame: UIImageView!
    @IBOutlet weak var calibrateToggleState: UISwitch!
    @IBOutlet var vispFrame: UIImageView!
    @IBOutlet weak var mbtDataToggleState: UISwitch!
    let avCapture = AVCapture()
    var mbtracker1 = MBTracker()
    var mbtracker2 = MBTracker()
    var apriltagdetector = AprilTag()
    var targetTagIds = [Int32]()
    var tagFamily = "36h11"
    var captureStatus = "RUN"
    var aprilDisplayMode:DisplayMode = .orientation
    var tagSize = 5.5 //mm
    var frontcam = false
    var img: UIImage!
    var calImages = Array<UIImage>()
    private lazy var previewLayer = avCapture.previewLayer
    private var drawings: [CAShapeLayer] = []


    // UDP Connection Variables
    var broadcastTags: UDPBroadcastConnection!
    var broadcastPoseConnection: UDPBroadcastConnection!
    var broadcastModelPoseConnection: UDPBroadcastConnection!
    let ipAddress = "192.168.0.14"
    var streamTagData = false
    var streamMbtData = false
    var streamFrames = false
    var collectImages = false
    var camIntrinsics:matrix_float3x3 = matrix_float3x3.init()
    var imageIndex:Int = 0             // this is the sequence number in the image stream
    var count = 0

    // Queue variables
    let trackingQueue = DispatchQueue(label: "apriltag", qos: DispatchQoS.userInitiated)

    // Timer Variables
    var poseTimer = Timer()
    var imageTimer = Timer()
    var tagFinderTimer = Timer()
    var fpsdisplayCount = 0;

    enum state {
        case state_config
        case state_detection
        case state_tracking
        case state_quit
    }
    var state_t = state.state_config
    var tracking1 = false
    var tracking2 = false

    struct AprilTagDataSwift {
        var number:Int32 = 0
        var posData = Array(repeating: 0.0, count: 16)
    }
    struct MBTrackerDataSwift {
        var tagNumber:Int32 = 0
        var modelPoseData = Array(repeating: 0.0, count: 16)
        var tagPoseData = Array(repeating: 0.0, count: 16)
    }
    struct TupletoArray {
        var tuple: (Double, Double, Double, Double, Double, Double,Double, Double, Double, Double, Double, Double,Double, Double, Double, Double)
        var array: [Double] {
            var tmp = self.tuple
            return [Double](UnsafeBufferPointer(start: &tmp.0, count: 16))
        }
    }

    struct Config {

        struct Ports {
            static let broadcast = UInt16(35601)
            static let broadcastModelPose = UInt16(35602)
            static let broadcastAprilTags = UInt16(7709)
        }

    }

    private var previousTimeInSeconds: Double = 0

    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self,
                                        selector: #selector(displayLoop))
        return displayLink;
    }()

    // MARK: UIViewController overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        avCapture.delegate = self
        tagDataToggleState.isOn = false
        mbtDataToggleState.isOn = false
        calibrateToggleState.isOn = false
        
//        self.showCameraFeed()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        avCapture.startCaptureSession()
        self.setupUdpConnections()
//        if let cadfile = Bundle.main.path(forResource: "cube_small", ofType: ".cao") {
//            mbtracker1.loadCADModel(cadfile)
//            mbtracker2.loadCADModel(cadfile)
//
//
//        }
        startLoop()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avCapture.stopCaptureSession()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.avCapture.stopCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }

    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
    }
    
    // MARK: - AVCaptureSession

    func capture(image: UIImage, pixelBuffer: CVPixelBuffer, intrinsic: matrix_float3x3) {
//        let start = Date()
        
        self.img = image
//        self.inFrame.image = image
        self.camIntrinsics = intrinsic
        var params = [
            intrinsic.columns.0.x,
            intrinsic.columns.1.y,
            intrinsic.columns.2.x,
            intrinsic.columns.2.y
        ]
        var procImage:UIImage = UIImage()
        
        // MARK: - State Machine
        switch state_t {
        case .state_config:
            print("CONFIG STATE")
            state_t = .state_detection
            
        case .state_detection:
            // april tag detection
//            print("DETECTION STATE")
            procImage = apriltagdetector.find(self.img, targetIds: &targetTagIds, count: Int32(targetTagIds.count), family: tagFamily, intrinsic: &params, tagSize: Int32(tagSize),display: aprilDisplayMode);
//            if (apriltagdetector.getNumberOfTags() == 2) {
//                let aprilTagPoseData = self.getAprilTagPoseData()
//                mbtracker1.initFromPose(NSMutableArray(array: aprilTagPoseData[0].posData))
//                mbtracker2.initFromPose(NSMutableArray(array: aprilTagPoseData[1].posData))
//
//                state_t = .state_tracking
//            }
            displayImage(vispImg: procImage)
            self.img = procImage
            
        case .state_tracking:
            // track model
            print("TRACKING STATE")
            procImage = apriltagdetector.find(self.img, targetIds: &targetTagIds, count: Int32(targetTagIds.count), family: tagFamily, intrinsic: &params, tagSize: Int32(tagSize),display: aprilDisplayMode);
            mbtracker1.setupCamParams(self.img, intrinsic: &params)
            mbtracker2.setupCamParams(self.img, intrinsic: &params)

            tracking1 = mbtracker1.trackModel()
            tracking2 = mbtracker2.trackModel()

            if (tracking1 && tracking2) {
                state_t = .state_tracking
            } else if (!tracking1 && !tracking2) {
                state_t = .state_detection
            }
            displayImage(vispImg: procImage)
        default:
            print("DEFAULT STATE")
        }

        if(collectImages && count < 1) {
            //            let path = (getDocumentsDirectory() as NSString).appendingPathComponent("calimg_" + String(count) + ".jpg")
            let image = self.img!

            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            print("Image " + String(self.count))
            self.count+=1

        }

//        let end = Date()
//        let fps = (1/((end.timeIntervalSince(start))))
//        frameRateLabel.text = String(format: "%5.2f FPS", fps)
    }

    // MARK: - UIActions
    @IBAction func buttonCameraSwap(_ sender: UIButton) {
//        state_t = .state_config
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

    @IBAction func mbtDataToggleTapped(_ sender: Any) {
        if (mbtDataToggleState.isOn) {
            poseTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitMbtPoseData), userInfo: nil, repeats: true)
            mbtDataToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
            self.streamMbtData = true
        } else if (!mbtDataToggleState.isOn){
            // stop
            mbtDataToggleState.removeTarget(self, action: #selector(scheduledTimerToTransmitData), for: .valueChanged)
            self.streamMbtData = false
        }
    }


    @IBAction func calibrateToggleTapped(_ sender: UISwitch) {
        if (calibrateToggleState.isOn) {
//            imageTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitImages), userInfo: nil, repeats: true)
//            calibrateToggleState.addTarget(self, action: #selector(self.scheduledTimerToTransmitData), for: .valueChanged)
//            self.streamFrames = true
            self.collectImages = true
        } else if (!calibrateToggleState.isOn){
            // stop
//            calibrateToggleState.removeTarget(self, action: #selector(scheduledTimerToTransmitData), for: .valueChanged)
//            self.streamFrames = false
            self.collectImages = false
            self.count = 0
        }
    }

    /// Initializes timers to send data at regular intervals
    @objc func scheduledTimerToTransmitData() {
        print("Checking to see what to transmit")
        poseTimer.invalidate()
        poseTimer = Timer()

        if mbtDataToggleState.isOn {
            poseTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitMbtPoseData), userInfo: nil, repeats: true)
        }
        imageTimer.invalidate()
        imageTimer = Timer()

        if calibrateToggleState.isOn {
            imageTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitImages), userInfo: nil, repeats: true)
        }
        tagFinderTimer.invalidate()

        if tagDataToggleState.isOn {
            tagFinderTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.transmitTags), userInfo: nil, repeats: true)
        }

    }

    @objc func transmitTags() {
        if (self.streamTagData == true) {
            trackingQueue.async {
//                let tagData = self.getAprilTagPoseData()
                let tagData = self.getDodecaPoseData()
                self.broadcastTags.sendBroadcast(self.formatAprilTagPoseData(tagArray: tagData,timeStamp: Double(Date().timeIntervalSince1970)))
            }
        }

    }

    @objc func transmitMbtPoseData() {
        if (self.streamMbtData == true) {
           trackingQueue.async {
                self.broadcastModelPoseConnection.sendBroadcast(self.formatModelPoseData(timeStamp: Double(Date().timeIntervalSince1970)))
            }
        }
    }

    @objc func transmitImages() {
        if (self.calibrateToggleState.isOn == true) {
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
                broadcastModelPoseConnection.sendBroadcast(udpPacketPayload)
                bytesSent += range.count
                packetIndex += 1
            }
            imageIndex += 1
//            print("stream images")
        }

    }

    func displayImage(vispImg: UIImage) {
        let flippedImage = UIImage(cgImage: (vispImg.cgImage!), scale: vispImg.scale, orientation: .upMirrored)
        if (frontcam) {
//            imageView.image = flippedImage
            imageView.image = vispImg

        } else {
            imageView.image = vispImg
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

        broadcastModelPoseConnection = UDPBroadcastConnection(port: Config.Ports.broadcastModelPose, ip: INADDR_BROADCAST) {(port: Int, response: [UInt8]) -> Void in
            print("Received from \(INADDR_BROADCAST):\(port):\n\n\(response)")
        }

        broadcastTags = UDPBroadcastConnection(port: Config.Ports.broadcastAprilTags, ip: INADDR_BROADCAST) {(port: Int, response: [UInt8]) -> Void in
            print("Received from \(INADDR_BROADCAST):\(port):\n\n\(response)")
        }
    }

    func formatAprilTagPoseData(tagArray: Array<AprilTagDataSwift>, timeStamp: Double) -> String {
        var poseMatrix = "START"
        if tagArray.count > 0 {
            for i in 0...tagArray.count-1 {
                let pose = tagArray[i].posData
                poseMatrix = poseMatrix + "," + String(format: "TAG,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", tagArray[i].number, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7], pose[8], pose[9], pose[10], pose[11], pose[12], pose[13], pose[14], pose[15], timeStamp)
            }
        }
        return poseMatrix
    }

    func getAprilTagPoseData() -> Array<AprilTagDataSwift> {
        var tagArray: Array<AprilTagDataSwift> = Array()
        let numTags = apriltagdetector.getNumberOfTags()

        if numTags > 0 {
            for i in 0...apriltagdetector.getNumberOfTags()-1 {
                let pose = TupletoArray(tuple: apriltagdetector.getAt(i).poseData).array
                let number = apriltagdetector.getAt(i).number
                let tagdata = AprilTagDataSwift(number: number, posData: pose)
                tagArray.append(tagdata)
            }
            return tagArray
        }
        return tagArray
    }
    
    func getDodecaPoseData() -> Array<AprilTagDataSwift> {
        var tagArray: Array<AprilTagDataSwift> = Array()
        let numMarkers = 1

        if numMarkers > 0 {
            for i in 0...numMarkers-1 {
                let pose = TupletoArray(tuple: apriltagdetector.getDodecaPoseEst().poseData).array
                let number = 1
                let tagdata = AprilTagDataSwift(number: Int32(number), posData: pose)
                tagArray.append(tagdata)
            }
            return tagArray
        }
        return tagArray
    }

    func formatModelPoseData(timeStamp: Double) -> String {
        var modelDataArray: Array<MBTrackerDataSwift> = Array()
        var poseMatrix = "START"

        let modelPose1 = TupletoArray(tuple: mbtracker1.getModelPoseData(0).poseData).array
        let modelPose2 = TupletoArray(tuple: mbtracker2.getModelPoseData(0).poseData).array

        let modeldata1 = MBTrackerDataSwift(modelPoseData: modelPose1)
        let modeldata2 = MBTrackerDataSwift(modelPoseData: modelPose2)

        modelDataArray.append(modeldata1)
        modelDataArray.append(modeldata2)

            for i in 0...modelDataArray.count-1 {
                let pose = modelDataArray[i].modelPoseData
                poseMatrix = poseMatrix + "," + String(format: "MODEL,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", modelDataArray[i].tagNumber, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7], pose[8], pose[9], pose[10], pose[11], pose[12], pose[13], pose[14], pose[15], timeStamp)
            }
        return poseMatrix
    }

//    func getModelPoseData(timeStamp: Double) -> String {
//        var modelDataArray: Array<MBTrackerDataSwift> = Array()
//        var poseMatrix = "START"
//
//        let modelPose = TupletoArray(tuple: mbtracker.getModelPoseData(0).poseData).array
//        let modeldata = MBTrackerDataSwift(modelPoseData: modelPose)
//            modelDataArray.append(modeldata)
//
//
//            for i in 0...modelDataArray.count-1 {
//                let pose = modelDataArray[i].modelPoseData
//                poseMatrix = poseMatrix + "," + String(format: "TAG,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f", modelDataArray[i].tagNumber, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7], pose[8], pose[9], pose[10], pose[11], pose[12], pose[13], pose[14], pose[15], timeStamp)
//            }
//        return poseMatrix
//    }

//    func getArTags(vispImage: UIImage, timeStamp: Double) -> JSON {
//        var tagArray: Array<AprilTagDataSwift> = Array()
//        let numTags = apriltagdetector.getNumberOfTags()
//        var frameData:[JSON] = Array()
//
//        if numTags > 0 {
//            for i in 0...apriltagdetector.getNumberOfTags()-1 {
//                let pose = TupletoArray(tuple: apriltagdetector.getAt(i).poseData).array
//                let number = apriltagdetector.getAt(i).number
//                let tagdata = AprilTagDataSwift(number: number, posData: pose)
//                tagArray.append(tagdata)
//            }
//
//            for i in 0...tagArray.count-1 {
//                let pose = tagArray[i].posData
//
//                let tagPositionData = JSON([
//                    "TAG_ID": tagArray[i].number
//                    ,"TimeStamp": timeStamp
//                    ,"PoseMatrix": [
//                         "pose_0" : pose[0]  ,"pose_1" : pose[1]  ,"pose_2" : pose[2]  ,"pose_3" : pose[3]
//                        ,"pose_4" : pose[4]  ,"pose_5" : pose[5]  ,"pose_6" : pose[6]  ,"pose_7" : pose[7]
//                        ,"pose_8" : pose[8]  ,"pose_9" : pose[9]  ,"pose_10": pose[10] ,"pose_11": pose[11]
//                        ,"pose_12": pose[12] ,"pose_13": pose[13] ,"pose_14": pose[14] ,"pose_15": pose[15]
//                    ]
//                ])
//                frameData.append(tagPositionData)
//            }
//        }
//
//        print (JSON(frameData).rawString()!)
//        return JSON(frameData)
//    }

    func getCameraIntrinsics() -> Data {
        let intrinsics = self.camIntrinsics
        let columns = intrinsics.columns
        let res = self.img.size
        let width = res.width
        let height = res.height

        return String(format: "%f,%f,%f,%f,%f,%f",  columns.0.x, columns.1.y, columns.2.x, columns.2.y, width, height).data(using: .utf8)!
    }


    private func startLoop() {
        previousTimeInSeconds = Date().timeIntervalSince1970
        displayLink.add(to: .current, forMode: .common)
    }

    @objc private func displayLoop() {
        let currentTimeInSeconds = Date().timeIntervalSince1970
        let elapsedTimeInSeconds = currentTimeInSeconds - previousTimeInSeconds
        previousTimeInSeconds = currentTimeInSeconds
        self.fpsdisplayCount = self.fpsdisplayCount + 1

        let actualFramesPerSecond = 1 / elapsedTimeInSeconds

        if (self.fpsdisplayCount == 5) {
            self.frameRateLabel.text = String(format: "%.2f FPS", actualFramesPerSecond)
            self.fpsdisplayCount = 0
        }
    }
}
