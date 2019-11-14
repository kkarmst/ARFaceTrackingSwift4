//
//  Camera Functions.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-11-01.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

import Foundation
import ARKit
var sceneView: ARSCNView!


   
   // Get video frames.

   
//   func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
//          //Calculate the size of the rotated view's containing box for our drawing space
//          let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
//          let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
//          rotatedViewBox.transform = t
//          let rotatedSize: CGSize = rotatedViewBox.frame.size
//          //Create the bitmap context
//          UIGraphicsBeginImageContext(rotatedSize)
//          let bitmap: CGContext = UIGraphicsGetCurrentContext()!
//          //Move the origin to the middle of the image so we will rotate and scale around the center.
//          bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
//          //Rotate the image context
//          bitmap.rotate(by: (degrees * CGFloat.pi / 180))
//          //Now, draw the rotated/scaled image into the context
//          bitmap.scaleBy(x: 1.0, y: -1.0)
//          bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
//          let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
//          UIGraphicsEndImageContext()
//          return newImage
//      }
