
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

#import "MBTracker.h"
#import "ImageConversion.h"
#import "ImageDisplay.h"
#import <AVFoundation/AVFoundation.h>

@interface MBTracker()
@end

@implementation MBTracker
@synthesize model;
@synthesize tracker;
@synthesize cMo;

// Camera Paramenters
float px;
float py;
float u0;
float v0;
vpCameraParameters cam;

double projection_error_threshold;
// Tag Detector Parameters
float quad_decimate;
int nThreads;
vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod;


// Initialize MBTacker Object
- (instancetype)init {
    if (self = [super init]) {
        _cMo = *new std::vector<vpHomogeneousMatrix>();
        _vpimg = NULL;
        projection_error_threshold = 45;
    }
    return self;
}

// Return specified april tag in an image
- (MBTrackerData)getModelPoseData:(int)index {
    NSArray *posePoints;
       
    std::stringstream buffer;
    buffer << cMo << std::endl;
    NSString *poseMatrix = [NSString stringWithCString:buffer.str().c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *updatePose1 = [poseMatrix stringByReplacingOccurrencesOfString:@"  " withString:@","];
    NSString *updatePose2 = [[updatePose1 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@","];
    
    posePoints = [updatePose2 componentsSeparatedByString:@","];
    for(Size j=0; j < 16; j++) {
        model.poseData[j] = [posePoints[j] doubleValue];
    }
    return model;
}

- (void) setupCamParams:(UIImage *)image intrinsic:(float *)param {

    // UIImage to vispImage
    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];

    // Define Cam Parmaters
    px = param[0];
    py = param[1];
    u0 = _vpimg.getWidth()/2;
    v0 = _vpimg.getHeight()/2;

    // Set Camera parameters
    cam.initPersProjWithoutDistortion(px,py,u0,v0);

    // set tracker cam params
     tracker.setCameraParameters(cam);
}

- (void) initFromPose: (NSMutableArray*)poseMatrix {

    unsigned long count = [poseMatrix count];
    double *array = new double[count];
    for(int i=0; i<count; i++) {
        array[i] = [[poseMatrix objectAtIndex:i] doubleValue];
    }
    
    std::vector<double> poseVec(array, array + count);
    
    cMo.buildFrom(vpPoseVector(vpHomogeneousMatrix(poseVec)));
    
//    printcMo(cMo);
    
    tracker.initFromPose(_vpimg, cMo);
    
}

- (void) loadCADModel: (NSString *)cadfilepath {
    
    vpMe me;
    me.setMaskSize(5);
    me.setMaskNumber(180);
    me.setRange(8);
    me.setThreshold(10000);
    me.setMu1(0.5);
    me.setMu2(0.5);
    me.setSampleStep(4);
    
    tracker.setMovingEdge(me);
    tracker.setTrackerType(vpMbGenericTracker::EDGE_TRACKER);
    tracker.setDisplayFeatures(true);
    tracker.setAngleAppear(vpMath::rad(70));
    tracker.setAngleDisappear(vpMath::rad(80));
    tracker.setNearClippingDistance(0.01);
    tracker.setFarClippingDistance(0.9);
    tracker.setClipping(vpMbtPolygon::FOV_CLIPPING);
                                  
    #ifdef __cplusplus
    std::string path = std::string([cadfilepath UTF8String]);
    #endif
    tracker.loadModel(path);
}

- (BOOL) trackModel{
    
//    // Convert UIImage to vispImage
//    UIGraphicsBeginImageContext(image.size);
//    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
//    image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];
    
    // Try and track object if cannot track return to detect apirl tag
    // Get cam paramters
    
//    printcMo(cMo);

//    tracker.setGoodMovingEdgesRatioThreshold(0.4);

    try {
        tracker.track(_vpimg);
//        tracker.testTracking();
    } catch (vpTrackingException &e) {
        std::cout << e.what() << std::endl;
        return false;
    }
    // get pose of model
    tracker.getPose(cMo);
//
    // compute tracking error
    double projection_error = tracker.computeCurrentProjectionError(_vpimg, cMo, cam);
    if (projection_error > projection_error_threshold) {
        std::cout << "Projection error: " << projection_error << " > " << "Projection error threshold: " << projection_error_threshold << std::endl;
        return false;
    }
//
//    // Display
//    tracker.display(_vpimg, cMo, cam, vpColor::red, 2);
//    vpDisplay::displayFrame(_vpimg, cMo, cam, 0.025, vpColor::none, 3);

    return true;
}

- (void) setVpImage:(UIImage *)image {
    // UIImage to vispImage
    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];
}

void printcMo(vpHomogeneousMatrix &cMo) {
     NSArray *posePoints;
    std::stringstream buffer;
    buffer << cMo << std::endl;
    NSString *poseMatrix = [NSString stringWithCString:buffer.str().c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *updatePose1 = [poseMatrix stringByReplacingOccurrencesOfString:@"  " withString:@","];
    NSString *updatePose2 = [[updatePose1 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@","];
    posePoints = [updatePose2 componentsSeparatedByString:@","];
    printf("cMo = [");
    for(int i = 0; i < cMo.size(); i++) {
        printf("%.21g,",[posePoints[i] doubleValue]);
        if (i == cMo.size()-1) {
           printf("%.21g]\n",[posePoints[i] doubleValue]);
        }
    }
}

void displayModelPose(vpMbGenericTracker *tracker,vpDetectorAprilTag *detector, vpHomogeneousMatrix *cMo,UIImage *image,double tagSize, int *targetIds, int targetCount) {
}
@end
