
import UIKit
import AVFoundation

protocol AVCaptureDelegate: class {
    func capture(image: UIImage, pixelBuffer: CVPixelBuffer, intrinsic:matrix_float3x3)
}

class AVCapture:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let userDefaults = UserDefaults.standard
    private var permissionGranted = true
    private let quality = AVCaptureSession.Preset.hd1280x720
    private var rotate:CGFloat = 90
    private var defaultPosition:AVCaptureDevice.Position = .front
    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var isImgProcessing:Bool = false
    private var videoInput:AVCaptureDeviceInput!
    private var videoDataOutput:AVCaptureVideoDataOutput!
    private var deviceDiscoverySession:AVCaptureDevice.DiscoverySession!
    lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    weak var delegate: AVCaptureDelegate?

    
    override init(){
        super.init()
        self.checkPermission()
        self.configureSession()
        
//        sessionQueue.async { [unowned self] in
//            self.configureSession()
//        }
    }
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        guard permissionGranted else { return }
        
        captureSession.sessionPreset = quality
        if let lastResolution = userDefaults.string(forKey: "Resolution") {
            changeResolution(quality: lastResolution)
        }
        
       captureSession.beginConfiguration()
        
//        let videoDevice = cameraWithPosition(position:defaultPosition)
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
                   fatalError()
               }
        do {
            self.videoInput = try AVCaptureDeviceInput.init(device: videoDevice)
        } catch {
            return
        }
        guard captureSession.canAddInput(videoInput) else {return}
        captureSession.addInput(videoInput)
        
        self.videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
 
        
        // Check we can add capture output
        guard captureSession.canAddOutput(videoDataOutput) else { return }
        captureSession.addOutput(videoDataOutput)

        if let connection = videoDataOutput.connections.first {
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                print("Camera Intrinsic Matrix Delivery is supported.")
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            } else {
                print("Camera Intrinsic Matrix Delivery is NOT supported.")
            }
        }
//        configureCameraForHighestFrameRate(device: videoDevice!)
        captureSession.commitConfiguration()
    }
    
    // 新しいキャプチャの追加で呼ばれる(1/30秒に１回)
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // check image processing flag.
        if self.isImgProcessing { return }
        
        // creat a pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError() }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])

        // get intrinsic matrix
        var matrix = matrix_float3x3.init()
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {
            matrix = camData.withUnsafeBytes { $0.pointee }
        }
        
        // Get UI Image
        guard let image = imageFromPixelBuffer(pixelBuffer: pixelBuffer) else { fatalError() }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer,[])
        
        // process image in main threads
        self.isImgProcessing = true
        DispatchQueue.main.async {
            
            let rotimage = self.imageRotatedByDegrees(oldImage: image, deg: 90)
            self.delegate?.capture(image: rotimage, pixelBuffer: pixelBuffer, intrinsic:matrix)
            
            // clear processing flag
            self.sessionQueue.async {
                self.isImgProcessing = false
            }
        }
    }
    
    func imageFromPixelBuffer(pixelBuffer :CVPixelBuffer) -> UIImage? {

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let pixelBufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelBufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageRect:CGRect = CGRect(x: 0, y: 0, width: pixelBufferWidth, height: pixelBufferHeight)
        let ciContext = CIContext.init()
        guard let cgImage = ciContext.createCGImage(ciImage, from: imageRect) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation:.up)
    }
    
    func changeResolution (quality: String) {
        if(quality == "High"
            && captureSession.sessionPreset != AVCaptureSession.Preset.photo) {
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
        }
        if(quality == "Medium"
            && captureSession.sessionPreset != AVCaptureSession.Preset.high) {
            captureSession.sessionPreset = AVCaptureSession.Preset.high
        }
    }
    
    func showCameraFeed(view: UIView) {
        self.previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = view.frame
    }
    
    func startCaptureSession() {
        if(!self.captureSession.isRunning){
            self.captureSession.startRunning()
            print("Capture session started")
        }    }
    
    func stopCaptureSession() {
        if(self.captureSession.isRunning){
            self.captureSession.stopRunning()
            print("Capture session stopped")
        }
    }
    
    func switchCameraPosition() {
        let currentVideoDevice = self.videoInput.device
        let currentPosition = currentVideoDevice.position
        
        let preferredPosition: AVCaptureDevice.Position
        let preferredDeviceType: AVCaptureDevice.DeviceType
        
        switch currentPosition {
        case .unspecified, .front:
            preferredPosition = .back
            preferredDeviceType = .builtInDualCamera
            
        case .back:
            preferredPosition = .front
            preferredDeviceType = .builtInTrueDepthCamera
            
        @unknown default:
            print("Unknown capture position. Defaulting to back, dual-camera.")
            preferredPosition = .back
            preferredDeviceType = .builtInDualCamera
        }
//        let devices = self.deviceDiscoverySession.devices
        var newVideoDevice: AVCaptureDevice? = nil
        
        // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
//        if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
//            newVideoDevice = device
//        } else if let device = devices.first(where: { $0.position == preferredPosition }) {
//            newVideoDevice = device
//        }
        
        if (currentVideoDevice.position == .back) {
            newVideoDevice = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            try! newVideoDevice?.lockForConfiguration()
            newVideoDevice?.focusMode = .continuousAutoFocus
            newVideoDevice?.unlockForConfiguration()
        } else if (currentVideoDevice.position == .front) {
            newVideoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            try! newVideoDevice?.lockForConfiguration()
            newVideoDevice?.focusMode = .continuousAutoFocus
            newVideoDevice?.unlockForConfiguration()

        }
        
        if let videoDevice = newVideoDevice {
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                
                self.captureSession.beginConfiguration()
                
                // Remove the existing device input first, because AVCaptureSession doesn't support
                // simultaneous use of the rear and front cameras.
                self.captureSession.removeInput(self.videoInput)
                
                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoInput = videoDeviceInput
                } else {
                    self.captureSession.addInput(self.videoInput)
                }
                 if let connection = videoDataOutput.connections.first {
                           if connection.isCameraIntrinsicMatrixDeliverySupported {
                               print("Camera Intrinsic Matrix Delivery is supported.")
                               connection.isCameraIntrinsicMatrixDeliveryEnabled = true
                           } else {
                               print("Camera Intrinsic Matrix Delivery is NOT supported.")
                           }
                       }
                
//                configureCameraForHighestFrameRate(device: newVideoDevice!)

                self.captureSession.commitConfiguration()
            } catch {
                print("Error occurred while creating video device input: \(error)")
            }
        }
    }
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        self.deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
        for device in deviceDiscoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    private func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
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
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func configureCameraForHighestFrameRate(device: AVCaptureDevice) {
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        
        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        
        if let bestFormat = bestFormat,
            let bestFrameRateRange = bestFrameRateRange {
            do {
                try device.lockForConfiguration()
                
                // Set the device's active format.
                device.activeFormat = bestFormat
                
                // Set the device's min/max frame duration.
                let duration = bestFrameRateRange.minFrameDuration
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                
                device.unlockForConfiguration()
            } catch {
                // Handle error.
            }
        }
    }
    
}
