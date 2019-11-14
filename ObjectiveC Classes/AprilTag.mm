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
#import <AVFoundation/AVFoundation.h>

@interface AprilTag()
@end

@implementation AprilTag
@synthesize tags;
@synthesize april;
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

- (UIImage *)find:(UIImage *)image targetIds:(int *)targetIds count:(int)targetCount
        family:(NSString *)tagFamilyName intrinsic:(float *)param tagSize:(int)tagSize display:(DisplayMode)modes{

    // 画像領域を確保
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // UIImageをvpImageにする
    _vpimg = [ImageConversion vpImageGrayFromUIImage:image];

    float px = param[0];
    float py = param[1];
    float u0 = _vpimg.getWidth()/2;
    float v0 = _vpimg.getHeight()/2;
    if(px == 0.0 && py == 0.0){
        px = 1515.0;
        py = 1515.0;
    }

    // AprilTag Family
//    vpDetectorAprilTag::vpAprilTagFamily tagFamily;
//    if([tagFamilyName  isEqual: @"36h11"]){
//        tagFamily = vpDetectorAprilTag::TAG_36h11;
//    } else if([tagFamilyName  isEqual: @"36h10"]){
//        tagFamily = vpDetectorAprilTag::TAG_36h10;
//    } else {
//        tagFamily = vpDetectorAprilTag::TAG_36h11;
//    }

    vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
    float quad_decimate = 3.0;
    int nThreads = 1;
    double vpTagSize = (double)tagSize / 1000.0; // (mm → m)

    // Initialize tag detector
//    vpDetectorAprilTag detector(tagFamily);
    detector->setAprilTagQuadDecimate(quad_decimate);
    detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
    detector->setAprilTagNbThreads(nThreads);

    // Set Camera parameters
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(px,py,u0,v0);

    // Detect all tags in frame
    detector->detect(_vpimg, vpTagSize, cam, _cMo);

    // 描画処理開始
    UIGraphicsBeginImageContext(image.size);
    [image drawAtPoint:CGPointMake(0,0)]; // まずは背景に元画像を表示
    CGContextRef context = UIGraphicsGetCurrentContext();

    // 描画設定
    NSDictionary *attrTagId =
    @{
      NSForegroundColorAttributeName : [UIColor blueColor],
      NSFontAttributeName : [UIFont boldSystemFontOfSize:50]
    };
    NSDictionary *attrDistance =
    @{
      NSForegroundColorAttributeName : [UIColor whiteColor],
      NSFontAttributeName : [UIFont boldSystemFontOfSize:50],
      NSBackgroundColorAttributeName: [UIColor blueColor]
      };

    // タグごとに描画
    int tagNums = (int)detector->getNbObjects();
    for(int i=0; i < tagNums; i++){

        // タグIDの取得 "36h11 id: 1" -> 1
        NSString * message = [NSString stringWithCString:detector->getMessage(i).c_str()
                encoding:[NSString defaultCStringEncoding]];
        NSArray *phases = [message componentsSeparatedByString:@" "];
        int detectedTagId = [phases[2] intValue];

        // フレームの描画
        UIColor *color = [UIColor systemOrangeColor];
        int tagLineWidth = 5;
        for(int n=0; n < targetCount; n++){
            // 合致するIDがあれば色変更
            if (detectedTagId == targetIds[n]) {
                color = [UIColor redColor];
                tagLineWidth = 15;
            }
        }
        std::vector<vpImagePoint> polygon = detector->getPolygon(i);
        CGContextSetLineWidth(context, tagLineWidth);
        CGContextSetStrokeColorWithColor(context, [color CGColor]);
        for (size_t j = 0; j < polygon.size(); j++) {

            CGContextMoveToPoint(context, polygon[j].get_u(), polygon[j] .get_v());
            CGContextAddLineToPoint(context, polygon[(j+1)%polygon.size()].get_u(), polygon[(j+1)%polygon.size()].get_v());

            CGContextStrokePath(context);
        }

        // tagIdの描画
        if(modes & DisplayMode_Id){
            NSString *tagIdStr = [NSString stringWithFormat:@"%d", detectedTagId];
            CGRect rect = CGRectMake(polygon[0].get_u(), polygon[0].get_v(), 600, 100);

            [tagIdStr drawInRect:CGRectIntegral(rect) withAttributes:attrTagId];
        }

        // カメラからの距離
        if(modes & DisplayMode_Distance){
            vpTranslationVector trans = _cMo[i].getTranslationVector();
            float distance = sqrt(trans[0]*trans[0] + trans[1]*trans[1] + trans[2]*trans[2]);
            NSString *meter = [NSString stringWithFormat:@"%.2fm", distance];
            vpImagePoint cog = detector->getCog(i);
            CGRect rect = CGRectMake(cog.get_u(), cog.get_v(), 600, 100);

            [meter drawInRect:CGRectIntegral(rect) withAttributes:attrDistance];
        }

        // 姿勢の描画
        if(modes & DisplayMode_Orientation){

            int tickness = 2;
            vpPoint o( 0.0,  0.0,  0.0);
            vpPoint x(vpTagSize,  0.0,  0.0);
            vpPoint y( 0.0, vpTagSize,  0.0);
            vpPoint z( 0.0,  0.0, vpTagSize);

            o.track(_cMo[i]);
            x.track(_cMo[i]);
            y.track(_cMo[i]);
            z.track(_cMo[i]);

            vpImagePoint ipo, ip1;

            vpMeterPixelConversion::convertPoint (cam, o.p[0], o.p[1], ipo);

            // Draw red line on top of original image
            vpMeterPixelConversion::convertPoint (cam, x.p[0], x.p[1], ip1);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetLineWidth(context, tickness);
            CGContextSetStrokeColorWithColor(context, [[UIColor redColor] CGColor]);
            CGContextMoveToPoint(context, ipo.get_u(), ipo.get_v());
            CGContextAddLineToPoint(context, ip1.get_u(), ip1.get_v());
            CGContextStrokePath(context);

            // Draw green line on top of original image
            vpMeterPixelConversion::convertPoint ( cam, y.p[0], y.p[1], ip1) ;
            context = UIGraphicsGetCurrentContext();
            CGContextSetLineWidth(context, tickness);
            CGContextSetStrokeColorWithColor(context, [[UIColor greenColor] CGColor]);
            CGContextMoveToPoint(context, ipo.get_u(), ipo.get_v());
            CGContextAddLineToPoint(context, ip1.get_u(), ip1.get_v());
            CGContextStrokePath(context);

            // Draw blue line on top of original image
            vpMeterPixelConversion::convertPoint ( cam, z.p[0], z.p[1], ip1) ;
            context = UIGraphicsGetCurrentContext();
            CGContextSetLineWidth(context, tickness);
            CGContextSetStrokeColorWithColor(context, [[UIColor blueColor] CGColor]);
            CGContextMoveToPoint(context, ipo.get_u(), ipo.get_v());
            CGContextAddLineToPoint(context, ip1.get_u(), ip1.get_v());
            CGContextStrokePath(context);

        }
    }

    // 新しい画像を上書き
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end
