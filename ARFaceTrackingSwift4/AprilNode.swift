//
//  AprilNode.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2020-03-03.
//  Copyright © 2020 Kieran Armstrong. All rights reserved.
//

import Foundation
import ARKit

class AprilNode : SCNNode {
    var size:CGFloat;
    public let id:Int;

    init(sz:CGFloat = 5.0, aprilId:Int = 1) {
        self.size = AprilProperty.MarkerSize;
        self.id = aprilId
        
        super.init();

        self.geometry = SCNBox(width: size, height: size, length: size, chamferRadius: 0)
        let mat = SCNMaterial()
        self.geometry?.materials = [mat]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
