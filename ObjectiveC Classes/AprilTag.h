//
//  AprilTag.h
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#ifdef __cplusplus
#import <visp3/visp.h>
#endif

@interface AprilTag : NSObject
+ (UIImage *)find:(UIImage *)sceneImage;

@end
