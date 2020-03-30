//  MBTracker.h
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//
#ifndef MBTracker_h
#define MBTracker_h
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#include <visp3/visp.h>
#include <vector>
#include <iostream>
using namespace std;
#endif

@interface MBTracker : NSObject {
//    NSMutableArray *_tags;
    #ifdef __cplusplus
    std::vector<vpHomogeneousMatrix> _cMo;
//    vpHomogeneousMatrix cMo;
//    std::vector<vpHomogeneousMatrix> cMo_model_vec;

    #endif
}

struct MBTrackerData {
    int tagNumber;
    double poseData[16];
//    double tagPoseData[16];
};

@property (nonatomic, strong) NSMutableArray *tags;
@property struct MBTrackerData model;
#ifdef __cplusplus
//@property (atomic, readonly) vpDetectorAprilTag* detector;
@property (atomic, readwrite) vpMbGenericTracker tracker;
@property (atomic, readonly) vpImage<unsigned char> vpimg;
@property (atomic, readwrite) vpHomogeneousMatrix cMo;
//@property (atomic, readonly) double vpTagSize;
#endif

- (void) setupCamParams:(UIImage *)image intrinsic:(float *)param;

- (void) initFromPose: (NSMutableArray *)poseMatrix;

- (BOOL) trackModel;

- (void) setVpImage:(UIImage *)image;

- (void) loadCADModel: (NSString *)cadfilepath;

- (struct MBTrackerData)getModelPoseData:(int)index;

@end
#endif /* MBTracker_h */
 
