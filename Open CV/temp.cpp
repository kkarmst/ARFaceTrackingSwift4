////
////  temp.cpp
////  ARFaceTrackingSwift4
////
////  Created by Kieran Armstrong on 2020-01-17.
////  Copyright © 2020 Kieran Armstrong. All rights reserved.
////
//
//#include "temp.hpp"
//
////  Copyright © 2019 Kieran Armstrong. All rights reserved.
////
//
//#import "MBTracker.h"
//#import "ImageConversion.h"
//#import "ImageDisplay.h"
//#import <AVFoundation/AVFoundation.h>
//
//#ifdef __cplusplus
//#import <functional>
//#endif
//
//@interface MBTracker()
//@end
//
//@implementation MBTracker
//@synthesize tags;
//@synthesize model;
//@synthesize tracker;
//@synthesize detector;
//@synthesize cMo;
//
//// Camera Paramenters
//float px;
//float py;
//float u0;
//float v0;
//vpCameraParameters cam;
//
//double projection_error_threshold;
//// Tag Detector Parameters
//float quad_decimate;
//int nThreads;
//vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod;
//
//// Initialize MBTacker Object
//- (instancetype)init {
//    if (self = [super init]) {
//        _tags = [[NSMutableArray alloc] init];
//
//        // Detector constructor
//        vpDetectorAprilTag::vpAprilTagFamily tagFamily = vpDetectorAprilTag::TAG_36h11;
//        detector = new vpDetectorAprilTag (tagFamily);
//
//        // Tracker Config
//        tracker = new vpMbGenericTracker(1,vpMbGenericTracker::EDGE_TRACKER);
//        // edges
//        vpMe me;
//        me.setMaskSize(5);
//        me.setMaskNumber(180);
//        me.setRange(12);
//        me.setThreshold(10000);
//        me.setMu1(0.5);
//        me.setMu2(0.5);
//        me.setSampleStep(4);
//        dynamic_cast<vpMbGenericTracker *>(tracker)->setMovingEdge(me);
//
//        // model definition
//        tracker->setDisplayFeatures(true);
//        tracker->setAngleAppear(vpMath::rad(70));
//        tracker->setAngleDisappear(vpMath::rad(80));
//
//        // Pose vector definition
//        _cMo = *new std::vector<vpHomogeneousMatrix>();
//        _vpimg = NULL;
//        projection_error_threshold = 40.0;
//    }
//    return self;
//}
//
//// Return number of apirl tags in each iamge
//- (int)getNumberOfTags {
//    return (int)detector->getNbObjects();
//}
//
//// Return specified april tag in an image
//- (MBTrackerData)getTagAtIndex:(int)index {
//    NSArray *posePoints;
//    int tagNumber;
//
//    NSString *message = [NSString stringWithCString:detector->getMessage(index).c_str() encoding:[NSString defaultCStringEncoding]];
//    [_tags addObject:message];
//    std::stringstream buffer;
//    buffer << _cMo[index] << std::endl;
//    NSString *poseMatrix = [NSString stringWithCString:buffer.str().c_str() encoding:[NSString defaultCStringEncoding]];
//    NSString *updatePose1 = [poseMatrix stringByReplacingOccurrencesOfString:@"  " withString:@","];
//    NSString *updatePose2 = [[updatePose1 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@","];
//    [_tags addObject:updatePose2];
//    NSArray *msg2 = [message componentsSeparatedByString:@" "];
//    tagNumber = [msg2[2] intValue];
//    posePoints = [updatePose2 componentsSeparatedByString:@","];
//    model.tagNumber = tagNumber;
//    for(Size j=0; j < 16; j++) {
//        model.tagPoseData[j] = [posePoints[j] doubleValue];
//    }
//    return model;
//}
//
//- (void) detect: (UIImage*)image targetIds:(int *)targetIds count:(int)targetCount
//family:(NSString *)tagFamilyName intrinsic:(float *)param tagSize:(int)tagSize {
//
//    // UIImage to vispImage
//    UIGraphicsBeginImageContext(image.size);
//    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
//    image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];
//
//    // Set detector params
//    detector->setAprilTagQuadDecimate(quad_decimate);
//    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
//    detector->setAprilTagNbThreads(nThreads);
//
//}
//
//- (void) setupCamParams:(UIImage *)image intrinsic:(float *)param tagSize:(int)tagSize {
//    UIGraphicsBeginImageContext(image.size);
//    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
//    image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//    // UIImage to vispImage
//    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];
//
//    // Define Cam Parmaters
//    px = param[0];
//    py = param[1];
//    u0 = _vpimg.getWidth()/2;
//    v0 = _vpimg.getHeight()/2;
//
//    // Define pose esimation parmaters
//    poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
//    quad_decimate = 3.0;
//    nThreads = 1;
//    _vpTagSize = (double)tagSize / 1000.0; // (mm → m)
//
//    // Set Camera parameters
//    cam.initPersProjWithoutDistortion(px,py,u0,v0);
//
//    // set tracker cam params
//     dynamic_cast<vpMbGenericTracker *>(tracker)->setCameraParameters(cam);
//}
//
//- (void) initFromPose: (int)index {
//
//    tracker->initFromPose(_vpimg, _cMo[index]);
//}
//
//- (void) loadCADModel: (NSString *)cadfilepath {
//    std::string path = std::string([cadfilepath UTF8String]);
//    tracker->loadModel(path);
//}
//
//- (BOOL) trackModel {
//    // Get cam paramters
//    tracker->getCameraParameters(cam);
//    // Try and track object if cannot track return to detect apirl tag
//
//    try {
//        tracker->track(_vpimg);
//    } catch (...) {
//        return false;
//    }
//    // get pose of model
//    tracker->getPose();
//
//    // compute tracking error
//    double projection_error = tracker->computeCurrentProjectionError(_vpimg, _cMo[0], cam);
//    if (projection_error > projection_error_threshold) {
//        return false;
//    }
//
//    // Display
////    tracker->display(_vpimg, cMo, cam, vpColor::red, 2);
////    vpDisplay::displayFrame(_vpimg, cMo, cam, 0.025, vpColor::none, 3);
//
//    return true;
//}
//
//@end
