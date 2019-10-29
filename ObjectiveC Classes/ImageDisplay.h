//
//  ImageDisplay.h
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

#import <UIKit/UIKit.h>
#ifdef __cplusplus
#import <visp3/visp.h>
#endif

@interface ImageDisplay : NSObject
#ifdef __cplusplus
+ (UIImage *)displayLine:(UIImage *)image :(vpImagePoint &)ip1 :(vpImagePoint &)ip2 :(UIColor*)color :(int)tickness;
+ (UIImage *)displayFrame:(UIImage *)image :(const vpHomogeneousMatrix &)cMo :(const vpCameraParameters &)cam
                         :(double) size :(int)tickness;
#endif
@end


