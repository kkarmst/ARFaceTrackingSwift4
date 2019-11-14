//
//  AprilTag.h
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//
#ifndef AprilTag_h
#define AprilTag_h
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <visp3/visp.h>
#import <vector>
#endif

typedef NS_OPTIONS(NSUInteger, DisplayMode){
    DisplayMode_Id          = 1 << 0,
    DisplayMode_Orientation = 1 << 1,
    DisplayMode_Distance    = 1 << 2
};


@interface AprilTag : NSObject {
    NSMutableArray *_tags;
    #ifdef __cplusplus
    std::vector<vpHomogeneousMatrix> _cMo;
    #endif
}

struct AprilTagData {
    int number;
    double poseData[16];
};

@property (nonatomic, strong) NSMutableArray *tags;
@property struct AprilTagData april;
#ifdef __cplusplus
@property (atomic, readonly) vpDetectorAprilTag* detector;
@property (atomic, readonly) vpImage<unsigned char> vpimg;

@property (atomic, readonly) std::vector<vpHomogeneousMatrix> cMo;
#endif

- (UIImage *)find: (UIImage*)image targetIds:(int *)targetIds count:(int)targetCount
family:(NSString *)tagFamilyName intrinsic:(float *)param tagSize:(int)tagSize display:(DisplayMode)modes;
- (int)getNumberOfTags;
- (struct AprilTagData)getTagAtIndex:(int)index;

@end
#endif /* AprilTag_h */
