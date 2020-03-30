////
////  Extensions.swift
////  FaceDataRecorder
////
////  Created by Elisha Hung on 2017/11/13.
////  Copyright © 2017 Elisha Hung. All rights reserved.
////
////  http://www.elishahung.com/
//
//import SceneKit
//import ARKit
//
//// Capture mode
//enum CaptureMode {
//    case record
//    case stream
//}
//
//// Every frame's capture data for streaming or save to text file later.
//struct CaptureData {
//    var vertices: [SIMD3<Float>]
//
//    var str : String {
//        let v = vertices.enumerated().map{ "\($0.element.x),\($0.element.y),\($0.element.z)" }.joined(separator: ",")
//        let datastr = "START,\(v),\(String(Double(Date().timeIntervalSince1970))),"
////        let v = vertices.enumerated().map{ "\($0.offset),\($0.element.x),\($0.element.y),\($0.element.z)" }.joined(separator: ",")
////        let datastr = "START,\(v),\(String(Double(Date().timeIntervalSince1970))),"
//        return v + "~"
//    }
//
////    var byte : [UInt8] {
////        let barray: [ <#type#>]
////        for v in vertices {
////
////        }
////    }
//
//}
//
//// Every frame's AprilTagData
//struct AprilTagData {
//
//}
//
//// Matrix
//extension simd_float4 {
//    var str : String {
//        return "\(self.x):\(self.y):\(self.z):\(self.w)"
//    }
//}
//
//// Camera's image format is CVPixelBuffer, convert it to cgImage for jpg compression
//extension UIImage {
//    convenience init (pixelBuffer: CVPixelBuffer) {
//        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
//        let context = CIContext(options: nil)
//        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
//        self.init(cgImage: cgImage!)
//    }
//}


// NEW FORMAT FOR DATA
//    var str : String {
////        let v = vertices.enumerated().map{ "\($0.element.x),\($0.element.y),\($0.element.z)" }.joined(separator: ",")
////        let datastr = "START,\(v),\(String(Double(Date().timeIntervalSince1970))),"
//        let v = vertices.enumerated().map{ "\($0.offset),\($0.element.x),\($0.element.y),\($0.element.z)" }.joined(separator: ",")
//        let datastr = "START,\(v),\(String(Double(Date().timeIntervalSince1970))),"
//        return datastr
//    }
