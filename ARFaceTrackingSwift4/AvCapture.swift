//
// This file is part of the groma software.
// Copyright © 2018 Aplix and/or its affiliates.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// version 2 as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//
// See https://groma.jp for more information.
//
//
// This file is copied and modified from original file, which is distributed under
// MIT License (https://github.com/furuya02/GekigaCamera/blob/master/LICENSE)
// and is copyrighted as follows.
//
// AvCapture.swift
//
// Created by hirauchi.shinichi on 2017/02/19.
// Copyright © 2017年 SAPPOROWORKS. All rights reserved.
//

import UIKit
import AVFoundation

protocol AVCaptureDelegate: class {
    func capture(image: UIImage, intrinsic:matrix_float3x3)
}

class AVCapture:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let userDefaults = UserDefaults.standard
    private var permissionGranted = false
    private let quality = AVCaptureSession.Preset.medium
    private var rotate:CGFloat = 90
    let position = AVCaptureDevice.Position.front
    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue")
    lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    weak var delegate: AVCaptureDelegate?
    //    lazy var framerate:Float
    
    override init(){
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
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
        
        let videoDevice = cameraWithPosition(position: position)
        let videoInput: AVCaptureInput!
        do {
            videoInput = try AVCaptureDeviceInput.init(device: videoDevice!)
        } catch {
            return
        }
        guard captureSession.canAddInput(videoInput) else {return}
//        configureCameraForHighestFrameRate(device: videoDevice!)
        captureSession.addInput(videoInput)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
 
        
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
    }
    
    // 新しいキャプチャの追加で呼ばれる(1/30秒に１回)
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var matrix = matrix_float3x3.init()
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {
            matrix = camData.withUnsafeBytes { $0.pointee }
        }
        
        let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
        delegate?.capture(image: image, intrinsic:matrix)
        
    }
    
    func imageFromSampleBuffer(sampleBuffer :CMSampleBuffer) -> UIImage {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // イメージバッファのロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // 画像情報を取得
        let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
        let width = UInt(CVPixelBufferGetWidth(imageBuffer))
        let height = UInt(CVPixelBufferGetHeight(imageBuffer))
        
        // ビットマップコンテキスト作成
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerCompornent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        let newContext = CGContext(data: base, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent), bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)! as CGContext
        
        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let imageRef = newContext.makeImage()!
        let oldImage = UIImage(cgImage: imageRef)
        let rotatedImage = imageRotatedByDegrees(oldImage: oldImage , deg: rotate)
        
        return rotatedImage
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
        self.captureSession.startRunning()
    }
    
    func stopCaptureSession() {
        self.captureSession.stopRunning()
        print("Session Stopped")
        
    }
    
    func switchCameraPosition() {
        // Indicate thta some changes will be made to the session
        self.captureSession.beginConfiguration()
        
        // Removing existing input
        let currentCameraInput: AVCaptureInput = self.captureSession.inputs.first!
        self.captureSession.removeInput(currentCameraInput)
        
        // Get new input
        var newCamera: AVCaptureDevice! = nil
        if let input = currentCameraInput as? AVCaptureDeviceInput {
            if (input.device.position == .back) {
                newCamera = cameraWithPosition(position: .front)
//                configureCameraForHighestFrameRate(device: newCamera!)

            } else {
                newCamera = cameraWithPosition(position: .back)
//                configureCameraForHighestFrameRate(device: newCamera!)

            }
        }
        // Add input to session
        var err: NSError?
        var newVideoInput: AVCaptureDeviceInput!
        do {
            newVideoInput = try AVCaptureDeviceInput(device: newCamera)
        } catch let err1 as NSError {
            err = err1
            newVideoInput = nil
        }
        
        if newVideoInput == nil || err != nil {
            print("Error creating capture device input: \(String(describing: err?.localizedDescription))")
        } else {
            
            self.captureSession.addInput(newVideoInput)
        }
        
        //Commit all the configuration changes at once
        self.captureSession.commitConfiguration()
    }
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
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
