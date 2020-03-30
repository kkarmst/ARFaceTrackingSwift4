//
//  AprilTag.m
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-10-27.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

#import "AprilTag.h"
#import "ImageConversion.h"
#import "ImageDisplay.h"
#import "ImageDisplay+withContext.h"
#import <AVFoundation/AVFoundation.h>
#import <Eigen/Core>
#import <unsupported/Eigen/NonLinearOptimization>

//using namespace std;

@interface AprilTag()
@end

@implementation AprilTag
@synthesize tags;
@synthesize april;
@synthesize dodeca;
@synthesize detector;
@synthesize cMo;

// Initialize AprilTag Object
- (instancetype)init {
    if (self = [super init]) {
        _tags = [[NSMutableArray alloc] init];
        vpDetectorAprilTag::vpAprilTagFamily tagFamily = vpDetectorAprilTag::TAG_36h11;
        detector = new vpDetectorAprilTag (tagFamily);
        _cMo = *new std::vector<vpHomogeneousMatrix>();
        _vpimg = NULL;
        NSString* path = [[NSBundle mainBundle] pathForResource:@"dodeca_centre_to_face_trans"
        ofType:@"txt"];
        _dodecaTcent = loadTransformations(path);
    }
    return self;
}

// Return number of apirl tags in each iamge
- (int)getNumberOfTags {
    return (int)detector->getNbObjects();
}

// Return specified april tag in an image
- (AprilTagData)getTagAtIndex:(int)index {
    NSArray *posePoints;
    int tagNumber;
    
    NSString *message = [NSString stringWithCString:detector->getMessage(index).c_str() encoding:[NSString defaultCStringEncoding]];
    [_tags addObject:message];
    std::stringstream buffer;
    buffer << _cMo[index] << std::endl;
    NSString *poseMatrix = [NSString stringWithCString:buffer.str().c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *updatePose1 = [poseMatrix stringByReplacingOccurrencesOfString:@"  " withString:@","];
    NSString *updatePose2 = [[updatePose1 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@","];
    [_tags addObject:updatePose2];
    NSArray *msg2 = [message componentsSeparatedByString:@" "];
    tagNumber = [msg2[2] intValue];
    posePoints = [updatePose2 componentsSeparatedByString:@","];
    april.number = tagNumber;
    for(Size j=0; j < 16; j++) {
        april.poseData[j] = [posePoints[j] doubleValue];
    }
    return april;
}

- (struct DodecaPose)getDodecaPoseEst {
    int index = 0;
    for (unsigned int i = 0; i < _dodecaPoseEst.getRows(); i++) {
        for (unsigned int j = 0; j < _dodecaPoseEst.getCols(); j++) {
            dodeca.poseData[index] = _dodecaPoseEst[i][j];
            index++;
        }
    }
    return dodeca;
}

- (UIImage *)find:(UIImage *)image targetIds:(int *)targetIds count:(int)targetCount
           family:(NSString *)tagFamilyName intrinsic:(float *)param tagSize:(int)tagSize display:(DisplayMode)modes{
        
    // Convert UI Image to vpImage Gray
    vpImage<unsigned char> I = [ImageConversion vpImageGrayFromUIImage:image];
    
    // Get cameral intrinsics from AVCaptureSession VideoDevice on each frame
    float px = param[0];
    float py = param[1];
    float u0 = I.getWidth()/2;
    float v0 = I.getHeight()/2;
    
    // Setup pose estimation method and parameters of april tags for VISP detector
    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::BEST_RESIDUAL_VIRTUAL_VS;
    float quad_decimate = 1.0;
    int nThreads = 3;
    double vpTagSize = (double)tagSize / 1000.0; // (mm → m)
    
    std::map<int, double> aprilTagSizes = {
      {0, vpTagSize},
      {1, vpTagSize},
      {2, vpTagSize},
      {3, vpTagSize},
      {4, vpTagSize},
      {5, vpTagSize},
      {6, vpTagSize},
      {7, vpTagSize},
      {8, vpTagSize},
      {9, vpTagSize},
      {10, vpTagSize},
      {11, vpTagSize},
    };

    
    // Initialize tag detector
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);
    
    // Set Camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(px,py,u0,v0);
    
    
    std::vector<int> tag_ids = *new std::vector<int>();
    std::vector<std::vector<vpPoint>> tagsPoints;
    std::vector<std::vector<vpImagePoint>> tag_corners_px_sp = *new std::vector< std::vector<vpImagePoint>>();
    
    std::vector<vpHomogeneousMatrix> T_cam_cent_estimates = *new std::vector<vpHomogeneousMatrix>();
    std::vector<vpHomogeneousMatrix> T_cent_face_estimates = *new std::vector<vpHomogeneousMatrix>();
    std::vector<vpHomogeneousMatrix> T_face_cent_estimates = *new std::vector<vpHomogeneousMatrix>();
    std::vector<vpHomogeneousMatrix> T_cam_cent_accepted;
    
    std::vector<vpHomogeneousMatrix> cMo_vec;
    
    // Detect all tags in frame
    if (detector->detect(I, vpTagSize, cam, cMo_vec)) {
        _cMo = cMo_vec;
        // Get tag data
        tag_ids = detector->getTagsId();
        tag_corners_px_sp = detector->getTagsCorners();
////        tagsPoints = detector->getTagsPoints3D(tag_ids,aprilTagSizes);
////        std::cout << tagsPoints[0][0].get_X() << " "
////                  << tagsPoints[0][0].get_Y() << " "
////                  << tagsPoints[0][0].get_Z() << " "
////                  << tagsPoints[0][0].get_W() << std::endl;
//
//
/* --------------------------------------------------------------------------------------------------------------- */
/* -------------------------------------- Find Average Poses Given BY VISP --------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------- */
        if (tag_ids.size() >= 2) {
            // The following is within the camera frame
            for (int m = 0; m < tag_ids.size(); m++) {
                // Get homogenous transformation matrix fro pose of april tag
                vpHomogeneousMatrix T_face_to_cam = cMo_vec[m];
                vpTranslationVector t = T_face_to_cam.getTranslationVector();

                // Scale t vec to mm
                T_face_to_cam[0][3] = t[0]*1000; T_face_to_cam[1][3] = t[1]*1000; T_face_to_cam[2][3] = t[2]*1000;
//                printTransformMatrix(T_face_to_cam,"T_face_to_cam");

                // Get transforms from centre of dodeca to face and face to centre of dodeca
                // VISP reports pose of the CAM wrt to the AprilTag T_tag_to_cam
                // We have the transform from the dodeca face to the centroid therefor to approx
                // the pose of the centriod wrt to the CAM: T_cam_to_centre = T_cam_to_face * T_tag_face_to_centre

                vpHomogeneousMatrix T_cent_to_face = _dodecaTcent[m];
//                printTransformMatrix(T_cent_to_face,"T_cent_to_face");

                vpHomogeneousMatrix T_face_to_cent = T_cent_to_face.inverse();
//                printTransformMatrix(T_face_to_cent,"T_face_to_cent");

                vpHomogeneousMatrix T_cam_to_face = T_face_to_cam.inverse();
//                printTransformMatrix(T_cam_to_face,"T_cam_to_face");

                vpHomogeneousMatrix T_cam_to_cent = T_cam_to_face * T_face_to_cent;
//                printTransformMatrix(T_cam_to_cent,"T_cam_to_cent");

                T_cam_cent_estimates.push_back(T_cam_to_cent);
                T_cent_face_estimates.push_back(T_cent_to_face);
                T_face_cent_estimates.push_back(T_face_to_cent);
            }

            // Find bad tags and return accepted indicies
            // TODO: Need to get transform matrix at TAG_ID not just count
            std::vector<int> tag_ids_accepted = removeBadAprilTagCentres(T_cam_cent_estimates, cam, _vpimg, tag_ids);
            std::vector<vpHomogeneousMatrix> T_cam_cent_accepted = *new std::vector<vpHomogeneousMatrix>();
            for (int i = 0; i < tag_ids_accepted.size(); i++) {
                T_cam_cent_accepted.push_back(T_cam_cent_estimates[i]);
//                printTransformMatrix(T_cam_cent_accepted[i],"T_cam_cent_accepted =");
            }

            vpHomogeneousMatrix T_cam_ball;
            if (tag_ids_accepted.size() > 1) {
                // Function to get averages of R and t and return T_cam_to_ball with slerp interpolation
                T_cam_ball = findTransformMatAverage(T_cam_cent_accepted);
                _dodecaPoseEst = T_cam_ball;
                printTransformMatrix(T_cam_ball,"Dodeca Pose Guess =");
            }
//
///* --------------------------------------------------------------------------------------------------------------- */
///* ----------------------------------------- Approximate Pose Estimation ----------------------------------------- */
///* --------------------------------------------------------------------------------------------------------------- */
//// Use the 6DOF dodecahedrion pose by minimizing the reprojection error, the l^2 difference between the projected
//// object points u(pose) and the observed image points u. Minimize using the Levenberg-Marquardt method.
//
//            /*
//             * GOAL: Given a non-linear equation
//             */
////            std::vector<float> corner_px_diffs = lmAPEDodecapen(T_cam_ball, T_cent_face_estimates, T_face_cent_estimates, cam, tag_corners_px_sp, tag_ids_accepted, vpTagSize);
//           // Provid
//           // Objective function: Array of the difference of projected object points in px space and the
//           // observed image points in px space.
//
//           // Inital Guess
////            vpQuaternionVector r_vec = vpQuaternionVector(T_cam_ball.getRotationMatrix());
////            vpTranslationVector t_vec = T_cam_ball.getTranslationVector();
////
////            vpMatrix X_guess(1,7);
////            X_guess[0][0] = r_vec[0]; X_guess[0][1] = r_vec[1]; X_guess[0][2] = r_vec[2]; X_guess[0][3] = r_vec[3];
////            X_guess[0][4] = t_vec[0]; X_guess[0][5] = t_vec[1]; X_guess[0][6] = t_vec[2];
////
////            // Image Points
////
////            LMFunctor functor;
////            functor.n = 7;
////            functor.m = 4*tag_ids_accepted.size();
////            functor.T_cent_face_estimates = T_cent_face_estimates;
////            functor.T_face_cent_estimates = T_face_cent_estimates;
////            functor.cam = cam;
////            functor.tag_corners_px_sp = tag_corners_px_sp;
////            functor.tag_ids_accepted = tag_ids_accepted;
////            functor.vpTagSize = vpTagSize;
////
//////            functor.measuredValues = lmAPEDodecapen(T_cam_ball, T_cent_face_estimates, T_face_cent_estimates, cam, tag_corners_px_sp, tag_ids_accepted, vpTagSize);
////            Eigen::NumericalDiff<LMFunctor> numDiff(functor);
////            Eigen::LevenbergMarquardt<Eigen::NumericalDiff<LMFunctor>,double> lm(numDiff);
////            lm.parameters.maxfev = 2000;
////            lm.parameters.xtol = 1.0e-10;
////
////            Eigen::VectorXf res = lm.minimize(X_guess);
//
//
//
//
        }
    }
    
    UIImage *img = [ImageConversion UIImageFromVpImageGray:I];

    return displayTagPose(img, detector, cam, cMo_vec, vpTagSize, DisplayMode_Orientation);
}

- (NSMutableArray *) estimatePose:(CVPixelBufferRef)pixelBuffer targetIds:(int *)targetIds count:(int)targetCount
family:(NSString *)tagFamilyName withIntrinsics:(matrix_float3x3)intrinsics tagSize:(Float64)markerSize {
    // Convert CVPixelBuffer in YCbCr format to vpImg
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);
    cv::Mat mat(height,width,CV_8UC1,baseaddress,0);
    
    vpImageConvert::convert(mat, _vpimg,true);
//    vpImageConvert::Yc
    
    float px = intrinsics.columns[0][0];
    float py = intrinsics.columns[1][1];
    float u0 = _vpimg.getWidth()/2;
    float v0 = _vpimg.getHeight()/2;
    
    if(px == 0.0 && py == 0.0){
        px = 1515.0;
        py = 1515.0;
    }
    
    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
    float quad_decimate = 3.0;
    int nThreads = 1;
    double vpTagSize = (double)markerSize / 1000.0; // (mm → m)
    
    // Initialize tag detector
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);
    
    // Set Camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(px,py,u0,v0);
    
    // Detect all tags in frame
     detector->detect(_vpimg, vpTagSize, cam, _cMo);
    
    // Release pixel buffer
     CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    
    NSMutableArray *arrayMatrix = [NSMutableArray new];
    if(detector->getNbObjects() == 0) {
        return  arrayMatrix;
    } else if (detector->getNbObjects() > 0) {
        std::cout << "Detected" << std::endl;
    }

    
//    cv::Mat intrinMat(3,3,CV_64F);
//    intrinMat.at<Float64>(0,0) = intrinsics.columns[0][0];
//    intrinMat.at<Float64>(0,1) = intrinsics.columns[1][0];
//    intrinMat.at<Float64>(0,2) = intrinsics.columns[2][0];
//    intrinMat.at<Float64>(1,0) = intrinsics.columns[0][1];
//    intrinMat.at<Float64>(1,1) = intrinsics.columns[1][1];
//    intrinMat.at<Float64>(1,2) = intrinsics.columns[2][1];
//    intrinMat.at<Float64>(2,0) = intrinsics.columns[0][2];
//    intrinMat.at<Float64>(2,1) = intrinsics.columns[1][2];
//    intrinMat.at<Float64>(2,2) = intrinsics.columns[2][2];
    
    
    return arrayMatrix;
}

- (UIImage *) estimatePoseFromCVBuffer:(CVPixelBufferRef)pixelBuffer :(float)fx :(float)fy :(float)cx :(float)cy {
        
//    DisplayMode mode = DisplayMode_Orientation;
    bool planer = CVPixelBufferIsPlanar(pixelBuffer);
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//
//    void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//    CGFloat width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
//    CGFloat height = CVPixelBufferGetHeightOfPlane(pixelBuffer,0);
//    cv::Mat mat(height,width,CV_8UC1,baseaddress,0);
    
  
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    // Convert to uiImage
    CIContext *ciContext = [CIContext contextWithCGContext:UIGraphicsGetCurrentContext() options:nil];
    CGImage *cgImage = [ciContext createCGImage:ciImage fromRect:ciImage.extent];
//    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage scale:1.0 orientation: UIImageOrientationUp];

//    UIImage *uiMirrorImage = [UIImage imageWithCGImage:cgImage scale:1.0 orientation: UIImageOrientationUpMirrored];
    vpImage<unsigned char> I = [ImageConversion vpImageGrayFromUIImage:uiImage];
    
//
    
//    int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
//    int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
//    int bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
//    UnsafeMutablePointer<UInt32> rawdata = UnsafeMutablePointer<UInt32>.alloc(bufferWidth * bufferHeight)
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB()
//    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
//    CGContextRef outContext = CGBitmapContextCreate(rawdata, bufferWidth, bufferHeight, bitsPerComponent, bytesPerRow, CGColorSpaceRef, <#uint32_t bitmapInfo#>)
//    cv::Mat mat = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,pixel, bytesPerRow); //put buffer in open cv, no memory copied
    //Processing here
    
//    vpImageConvert::convert(mat, _vpimg);
    
    // Detect AprilTag
    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
    double tagSize = 0.015; // Size of OccamLab april tags
    float quad_decimate = 3.0;
    int nThreads = 1;
    
    // Set camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(fx, fy, cx, cy); // Gets camera intrinsics from ARFrame
    
    // Initialize apriltag detector
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);
    
    // Detect all the tags in the image
    bool tagfound = detector->detect(I, tagSize, cam, _cMo);
    if (tagfound) {
        std::cout << "Tag Found" << std::endl;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    UIImage *img = [ImageConversion UIImageFromVpImageGray:I];
    
    return img;
}

- (UIImage *) estimatePoseFromUIImage:(UIImage *)image :(float)fx :(float)fy :(float)cx :(float)cy {
//    DisplayMode mode = DisplayMode_Orientation;
    vpImage<unsigned char> I = [ImageConversion vpImageGrayFromUIImage:image];
    
    // Detect AprilTag
    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
    double tagSize = 0.015; // Size of OccamLab april tags
    float quad_decimate = 3.0;
    int nThreads = 1;
    
    // Set camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(fx, fy, cx, cy); // Gets camera intrinsics from ARFrame
    
    // Initialize apriltag detector
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);
    
    // Detect all the tags in the image
    bool tagfound = detector->detect(I, tagSize, cam, _cMo);
    if (tagfound) {
        std::cout << "Tag Found" << std::endl;
    }
    
    UIImage *img = [ImageConversion UIImageFromVpImageGray:I];
    
//    return displayTagPose(detector, cam, _cMo, img, tagSize, 0, 0, mode);
    return img;
}

- (SCNMatrix4) transformMatrixFromPixelBuffer:(CVPixelBufferRef)pixelBuffer withIntrinsics:(matrix_float3x3)intrinsics {
        
    // Build cv intrinsic and distance matricies
    cv::Mat intrinMat(3,3,CV_64F);
    cv::Mat distMat(3,3,CV_64F);
    
    // Convert scenekit matrix to cv matrix
    intrinMat.at<Float64>(0,0) = intrinsics.columns[0][0];
    intrinMat.at<Float64>(0,1) = intrinsics.columns[1][0];
    intrinMat.at<Float64>(0,2) = intrinsics.columns[2][0];
    intrinMat.at<Float64>(1,0) = intrinsics.columns[0][1];
    intrinMat.at<Float64>(1,1) = intrinsics.columns[1][1];
    intrinMat.at<Float64>(1,2) = intrinsics.columns[2][1];
    intrinMat.at<Float64>(2,0) = intrinsics.columns[0][2];
    intrinMat.at<Float64>(2,1) = intrinsics.columns[1][2];
    intrinMat.at<Float64>(2,2) = intrinsics.columns[2][2];
    
    distMat.at<Float64>(0,0) = 0;
    distMat.at<Float64>(0,1) = 0;
    distMat.at<Float64>(0,2) = 0;
    distMat.at<Float64>(0,3) = 0;
    
    float fx,fy,cx,cy;
    fx = intrinsics.columns[0][0];
    fy = intrinsics.columns[1][1];
    cx = intrinsics.columns[2][0];
    cy = intrinsics.columns[2][1];
    
    // Convert pixel buffer to cv matrix
    void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);
    cv::Mat mat(height,width,CV_8UC1,baseaddress,0);
    
    
    vpImage<unsigned char> I;
    vpImageConvert::convert(mat, I);
    
    // Detect AprilTag
    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
    double tagSize = 0.005; // Size of OccamLab april tags
    float quad_decimate = 3.0;
    int nThreads = 1;
    
    // Set camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(fx, fy, cx, cy); // Gets camera intrinsics from ARFrame
    
    // Initialize apriltag detector
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);
    
    // Detect all the tags in the image
    std::vector<int> ids;
    std::vector<std::vector<vpImagePoint>> corners;
    std::vector<vpHomogeneousMatrix> cMo_vec = *new std::vector<vpHomogeneousMatrix>();
    if (detector->detect(I, tagSize, cam, cMo_vec)) {
        std::cout << "April Tags Found: " << (int)detector->getNbObjects() << std::endl;
        
        int tagNums = (int)detector->getNbObjects();
        for(int i=0; i < tagNums; i++){
            // Get corner points on each tag
            corners.push_back(detector->getPolygon(i));
        }
        
        std::cout << "End" << std::endl;

    }
    

    
    return SCNMatrix4Identity;
}


- (UIImage *)vispImageToUIImage:(CVPixelBufferRef) pixelBuffer {
    
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);

    // Set the following dict on AVCaptureVideoDataOutput's videoSettings to get YUV output
    // @{ kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange }

    NSAssert(format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, @"Only YUV is supported");

    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);
    cv::Mat mat(height,width,CV_8UC1,baseaddress,0);
    
    vpImage<unsigned char> Ig;
    vpImageConvert::convert(mat, Ig);
    
    // Release pixel buffer
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    UIImage *img = [ImageConversion UIImageFromVpImageGray:Ig];
    
    return img;
}


//UIImage* displayTagPose(vpDetectorAprilTag *detector,vpCameraParameters cam,std::vector<vpHomogeneousMatrix> &_cMo,UIImage *image,double vpTagSize, int *targetIds, int targetCount, DisplayMode modes)

UIImage* displayTagPose(UIImage* img, vpDetectorAprilTag* detector, vpCameraParameters cam, std::vector<vpHomogeneousMatrix> cMo_vec, double vpTagSize, DisplayMode mode) {
    
    
    // starts drawing
    UIGraphicsBeginImageContext(img.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // draw original image in the current context.
    [img drawAtPoint:CGPointMake(0,0)];
    
    int tagNums = (int) detector->getNbObjects();
    for(int i=0; i < tagNums; i++){
        
        // parameters
        std::vector<vpImagePoint> polygon = detector->getPolygon(i);
        vpImagePoint cog = detector->getCog(i);
        vpTranslationVector trans = cMo_vec[i].getTranslationVector();
        UIColor *mainColor = [UIColor orangeColor];
        int tagLineWidth = 3;
        
        // tag Id from message: "36h11 id: 1" -> 1
        NSString * message = [NSString stringWithCString:detector->getMessage(i).c_str() encoding:[NSString defaultCStringEncoding]];
        NSArray *phases = [message componentsSeparatedByString:@" "];
        int detectedTagId = [phases[2] intValue];
        
        // draw tag frame
        [ImageDisplay displayLineWithContext:context :polygon :mainColor :tagLineWidth];
        
        // draw tag id
        if (mode == DisplayMode_Id) {
            NSString *tagIdStr = [NSString stringWithFormat:@"%d", detectedTagId];
            [ImageDisplay displayText:tagIdStr :polygon[0].get_u() :polygon[0].get_v() - 50 :600 :100 :mainColor :[UIColor clearColor]];
        }
        
        // draw xyz cordinate.
        if (mode == DisplayMode_Orientation) {
            [ImageDisplay displayFrameWithContext:context :cMo_vec[i] :cam :vpTagSize :3];
        }
        
        // draw distance from camera.
        if (mode == DisplayMode_Distance) {
            NSString *meter = [NSString stringWithFormat:@"(%.2f,%.2f,%.2f)",trans[0],trans[1],trans[2]];
            [ImageDisplay displayText:meter :cog.get_u() :cog.get_v() +50 :600 :100 :[UIColor whiteColor] :[UIColor blueColor]];
        }
    }
    
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

std::vector<vpHomogeneousMatrix> loadTransformations(NSString *path) {
    std::vector<vpHomogeneousMatrix> T_cent = *new std::vector<vpHomogeneousMatrix>();
    
    // read everything from text
    NSString* fileContents =
          [NSString stringWithContentsOfFile:path
           encoding:NSUTF8StringEncoding error:nil];

    // first, separate by new line
    NSArray* allLinedStrings =
          [fileContents componentsSeparatedByCharactersInSet:
          [NSCharacterSet newlineCharacterSet]];
    
    for (int i = 0; i < allLinedStrings.count; i++) {
        NSRange isRange = [allLinedStrings[i] rangeOfString:@"# FACE_ID=" options:NSCaseInsensitiveSearch];
        if (isRange.location == 0) {
            NSArray *row1 = [allLinedStrings[i+1] componentsSeparatedByString:@" "];
            NSArray *row2 = [allLinedStrings[i+2] componentsSeparatedByString:@" "];
            NSArray *row3 = [allLinedStrings[i+3] componentsSeparatedByString:@" "];
            
            vpHomogeneousMatrix M;
            M[0][0] = [row1[0] doubleValue]; M[0][1] = [row1[1] doubleValue]; M[0][2] = [row1[2] doubleValue]; M[0][3] = [row1[3] doubleValue];
            M[1][0] = [row2[0] doubleValue]; M[1][1] = [row2[1] doubleValue]; M[1][2] = [row2[2] doubleValue]; M[1][3] = [row2[3] doubleValue];
            M[2][0] = [row3[0] doubleValue]; M[2][1] = [row3[1] doubleValue]; M[2][2] = [row3[2] doubleValue]; M[2][3] = [row3[3] doubleValue];
            
            T_cent.push_back(vpHomogeneousMatrix(M));
        }
    }
    
    return T_cent;
}

std::vector<int> removeBadAprilTagCentres(std::vector<vpHomogeneousMatrix> T_cam_cent_estimates, vpCameraParameters cam, vpImage<unsigned char> img, std::vector<int> tag_ids) {
    /* Takes in the transforms for the april tag centres and returns the accepted transforms
     * that are not too far away from others.
     */
    
    // Create matrix with length of centre points
    // Never more than 4 tags can be seen
    // float M_centre_in_R3[4][2];
    std::vector<vpImagePoint> centres_in_px_sp = *new std::vector<vpImagePoint>();
    std::vector<int> good_tag_ids = *new std::vector<int>();
    
    int max_dist = 100; // pixels
    for (int i = 0; i < tag_ids.size(); i++) {
        // Get centre translation vec
        vpTranslationVector centre_R3 = T_cam_cent_estimates[i].getTranslationVector();
        // Project (x,y,z) -> (j,i) on image plane
        vpImagePoint centre_px_space = *new vpImagePoint();
        vpMeterPixelConversion::convertPointWithoutDistortion(cam, centre_R3[0]/1000, centre_R3[1]/1000, centre_px_space);
        // Collect pixel coordiantes for each tag
        centres_in_px_sp.push_back(centre_px_space);
    }
    // Calculate euclidean distance between pixels
    int count = 0;
    for(int i = 0; i < tag_ids.size(); i++) {
        for(int j = 0; j < tag_ids.size(); j++) {
            float dist = vpImagePoint::distance(centres_in_px_sp[i],centres_in_px_sp[j]);
             std::cout << dist << std::endl;
            if (dist > 0 && dist < max_dist) {
                count++;
            }
        }
        if (count != 0) {
            good_tag_ids.push_back(tag_ids[i]);
        }
        count = 0;
    }

    return good_tag_ids;
}

vpHomogeneousMatrix findTransformMatAverage(std::vector<vpHomogeneousMatrix> T_cam_cent_accepted) {
    vpHomogeneousMatrix T_cam_ball;
    T_cam_ball.eye();
    
    // Convert transformations to quaternion and trans components
    std::vector<vpQuaternionVector> r_vecs = *new std::vector<vpQuaternionVector>();
    std::vector<vpTranslationVector> t_vecs = *new std::vector<vpTranslationVector>();
    
    for (int i = 0; i < T_cam_cent_accepted.size(); i++) {
        r_vecs.push_back(vpQuaternionVector(T_cam_cent_accepted[i].getRotationMatrix()));
        t_vecs.push_back(T_cam_cent_accepted[i].getTranslationVector());
    }
    
    // Use slerp interpolation to average rotations
    vpQuaternionVector quart1 = r_vecs[0];
    vpQuaternionVector quart_avg;
    for (int i = 0; i < T_cam_cent_accepted.size()-1; i++) {
        vpQuaternionVector quart2 = r_vecs.at(i+1);
        quart_avg = slerp(quart2,quart1,0.5);
    }
    
    vpRotationMatrix R_avg = vpRotationMatrix(quart_avg);
    vpTranslationVector t_avg = vpTranslationVector::mean(t_vecs);
    T_cam_ball = vpHomogeneousMatrix(t_avg, R_avg);
    
    return T_cam_ball;
    
}

Eigen::VectorXf lmAPEDodecapen(vpMatrix X_guess, std::vector<vpHomogeneousMatrix> T_cent_face_estimates, std::vector<vpHomogeneousMatrix> T_face_cent_estimates, vpCameraParameters cam, std::vector<std::vector<vpImagePoint>> tag_corners_px_sp, std::vector<int> tag_ids_accepted, double vpTagSize) {
    /* Function to get the objective function for APE step of the apgorithm.
     * Returns a std vec of differences between pixels
     */
    
    // Get T_cent_face and T_face_cent
    // Caclucate corners in R3 from T_cent_face and the marker size
    vpMatrix corners_HOMOG;
    vpMatrix tag_corners_stacked_R3;
    vpMatrix tag_corners_stracked_px_sp;
    vpHomogeneousMatrix T_cam_ball = vpHomogeneousMatrix(vpTranslationVector(X_guess[0][4], X_guess[0][5], X_guess[0][6]), vpQuaternionVector(X_guess[0][0], X_guess[0][1], X_guess[0][2], X_guess[0][3]));
    
    // stack image corner coordinates in pixel space
    for (int i = 0; i < tag_corners_px_sp.size(); i++) {
        for (int j = 0; j < 4; j++) {
            vpMatrix row(1,2);
            row[0][0] = tag_corners_px_sp[i][j].get_j(); row[0][1] = tag_corners_px_sp[i][j].get_i();
            printMatrix(row, "row");
            tag_corners_stracked_px_sp.stack(row);
        }
    }

    for (int i = 0; i < tag_ids_accepted.size(); i++) {
//        printMatrix(T_face_cent_estimates[i], "T_face_cent_estimates");
        vpMatrix corners = tagCornersInCamFrame(T_face_cent_estimates[i],vpTagSize);
//        printMatrix(corners, "corners_R2");
        vpMatrix::mult2Matrices(T_cam_ball, corners, corners_HOMOG);
//        printMatrix(corners_HOMOG, "corners_HOMOG");
        vpMatrix corners_R3 = corners_HOMOG.t().extract(0, 0, 4, 3);
//        printMatrix(corners_R3, "corners_from_cam");
        tag_corners_stacked_R3.stack(corners_R3);
//        tag_corners.push_back(corners_R3);
    }
//    printMatrix(tag_corners_stacked_R3, "tag_corners_stacked_R3");
//    printMatrix(tag_corners_stracked_px_sp, "tag_corners_stracked_px_sp");
    
    // project tag corners in r3 to pixel space
    vpMatrix projected_in_px_sp;
    
    for (int i = 0; i < tag_corners_stacked_R3.getRows(); i++) {
        vpImagePoint corner_in_px_space = *new vpImagePoint();
        vpMeterPixelConversion::convertPointWithoutDistortion(cam, tag_corners_stacked_R3[i][0]/1000, tag_corners_stacked_R3[i][1]/1000, corner_in_px_space);
        vpMatrix row(1,2);
        row[0][0] = corner_in_px_space.get_j(); row[0][1] = corner_in_px_space.get_i();
        projected_in_px_sp.stack(row);
    }
    
    vpMatrix diff = tag_corners_stracked_px_sp-projected_in_px_sp;
    vpRowVector norm_v;
    for (int i = 0; i < diff.getRows(); i++)  {
        double norm = diff.getRow(i).frobeniusNorm();
        norm_v.stack(norm);
    }
    
    Eigen::VectorXf norm_eigen_v(diff.getRows());
    for (int i = 0; i < diff.getRows(); i++)  {
        norm_eigen_v(i) = norm_v[i];
    }
    
    std::cout << "norm_v = "; norm_v.matlabPrint(std::cout);
    return norm_eigen_v;
}

vpMatrix tagCornersInCamFrame(vpHomogeneousMatrix T_face_to_cent, double tagSize) {
 
    vpMatrix M(4,4);
    double tagSize_mm = tagSize * 1000;
    M[0][0] = -tagSize_mm/2.0; M[0][1] =  tagSize_mm/2.0; M[0][2] = 0.0; M[0][3] = 1.0;
    M[1][0] =  tagSize_mm/2.0; M[1][1] =  tagSize_mm/2.0; M[1][2] = 0.0; M[1][3] = 1.0;
    M[2][0] =  tagSize_mm/2.0; M[2][1] = -tagSize_mm/2.0; M[2][2] = 0.0; M[2][3] = 1.0;
    M[3][0] = -tagSize_mm/2.0; M[3][1] = -tagSize_mm/2.0; M[3][2] = 0.0; M[3][3] = 1.0;
    
    printMatrix(T_face_to_cent, "T_face_cent");
    printMatrix(M,"corners_R2");
    vpMatrix corners_cam_frame;
    vpMatrix::mult2Matrices(T_face_to_cent, M.t(), corners_cam_frame);
    
    printMatrix(corners_cam_frame,"Corners Cam Frame");
    return corners_cam_frame;
}


void printTransformMatrix(vpHomogeneousMatrix M, std::string name) {
    std::cout << name << ": " << std::endl;
    for (unsigned int i = 0; i < M.getRows(); i++) {
        for (unsigned int j = 0; j < M.getCols(); j++) {
            std::cout << M[i][j] << " ";
        }
        std::cout << std::endl;
    }
}

void printMatrix(vpMatrix M, std::string name) {
    std::cout << name << ": " << std::endl;
    for (unsigned int i = 0; i < M.getRows(); i++) {
        for (unsigned int j = 0; j < M.getCols(); j++) {
            std::cout << M[i][j] << " ";
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

vpQuaternionVector slerp(vpQuaternionVector q0, vpQuaternionVector q1, double t) {
    vpColVector result;
    vpColVector v0 = q0;
    vpColVector v1 = q1;
    // Only unit quaternions are valid rotations.
    // Normalize to avoid undefined behavior.
    v0.normalize();
    v1.normalize();
    
    // Compute the cosine of the angle between the two vectors.
    double dot = vpColVector::dotProd(v0, v1);
    
    // If the dot product is negative, slerp won't take
    // the shorter path. Note that v1 and -v1 are equivalent when
    // the negation is applied to all four components. Fix by
    // reversing one quaternion.
    if (dot < 0.0f) {
        v1 = -v1;
        dot = -dot;
    }
    
    const double DOT_THRESHOLD = 0.9995;
    if (dot > DOT_THRESHOLD) {
        // If the inputs are too close for comfort, linearly interpolate
        // and normalize the result.
        
        vpColVector result = v0 + t*(v1 - v0);
        result.normalize();
        return vpQuaternionVector(result);
    }
    
    // Since dot is in range [0, DOT_THRESHOLD], acos is safe
    double theta_0 = acos(dot);        // theta_0 = angle between input vectors
    double theta = theta_0*t;          // theta = angle between v0 and result
    double sin_theta = sin(theta);     // compute this value only once
    double sin_theta_0 = sin(theta_0); // compute this value only once
    
    double s0 = cos(theta) - dot * sin_theta / sin_theta_0;  // == sin(theta_0 - theta) / sin(theta_0)
    double s1 = sin_theta / sin_theta_0;
    
    result = (s0 * v0) + (s1 * v1);
    return vpQuaternionVector(result);
}

// Generic functor
template<typename _Scalar, int NX = Eigen::Dynamic, int NY = Eigen::Dynamic>
struct Functor
{
typedef _Scalar Scalar;
enum {
    InputsAtCompileTime = NX,
    ValuesAtCompileTime = NY
};
typedef Eigen::Matrix<Scalar,InputsAtCompileTime,1> InputType;
typedef Eigen::Matrix<Scalar,ValuesAtCompileTime,1> ValueType;
typedef Eigen::Matrix<Scalar,ValuesAtCompileTime,InputsAtCompileTime> JacobianType;

int m_inputs, m_values;

Functor() : m_inputs(InputsAtCompileTime), m_values(ValuesAtCompileTime) {}
Functor(int inputs, int values) : m_inputs(inputs), m_values(values) {}

int inputs() const { return m_inputs; }
int values() const { return m_values; }

};

struct LMFunctor : Functor<double>
{
    LMFunctor(void) : Functor<double>(6,6) {}
    
    // 'm' pairs of (x, f(x))
    std::vector<vpHomogeneousMatrix> T_cent_face_estimates;
    std::vector<vpHomogeneousMatrix> T_face_cent_estimates;
    vpCameraParameters cam;
    std::vector<std::vector<vpImagePoint>> tag_corners_px_sp;
    std::vector<int> tag_ids_accepted;
    double vpTagSize;

    // Compute 'm' errors, one for each  corner data point, for the given parameter values in 'x'
    int operator()(const vpMatrix &x, Eigen::VectorXf &fvec) const
    {
        // 'x' has dimensions n x 1
        // It contains the current estimates for the parameters.

        // 'fvec' has dimensions m x 1
        // It will contain the error for each data point.
        
        fvec = lmAPEDodecapen(x, T_cent_face_estimates, T_face_cent_estimates, cam, tag_corners_px_sp, tag_ids_accepted,vpTagSize);
//        fvec(1) = 0;
        return 0;
    }

    // Compute the jacobian of the errors
//    int df(const Eigen::VectorXf &x, Eigen::MatrixXf &fjac) const
//    {
//        // 'x' has dimensions n x 1
//        // It contains the current estimates for the parameters.
//
//        // 'fjac' has dimensions m x n
//        // It will contain the jacobian of the errors, calculated numerically in this case.
//
//        float epsilon;
//        epsilon = 1e-5f;
//
//        for (int i = 0; i < x.size(); i++) {
//            Eigen::VectorXf xPlus(x);
//            xPlus(i) += epsilon;
//            Eigen::VectorXf xMinus(x);
//            xMinus(i) -= epsilon;
//
//            Eigen::VectorXf fvecPlus(values());
//            operator()(xPlus, fvecPlus);
//
//            Eigen::VectorXf fvecMinus(values());
//            operator()(xMinus, fvecMinus);
//
//            Eigen::VectorXf fvecDiff(values());
//            fvecDiff = (fvecPlus - fvecMinus) / (2.0f * epsilon);
//
//            fjac.block(0, i, values(), 1) = fvecDiff;
//        }

//        return 0;
//    }

    // Number of data points, i.e. values.
    int m;

    // Returns 'm', the number of values.
    int values() const { return m; }

    // The number of parameters, i.e. inputs.
    int n;

    // Returns 'n', the number of inputs.
    int inputs() const { return n; }

};


@end
