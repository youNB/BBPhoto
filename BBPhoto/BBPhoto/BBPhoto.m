//
//  BBPhoto.m
//  BBPhoto
//
//  Created by 程肖斌 on 2019/1/24.
//  Copyright © 2019年 ICE. All rights reserved.
//

#import "BBPhoto.h"

@implementation BBPhoto

+ (BBPhoto *)sharedManager{
    static BBPhoto *manager       = nil;
    static dispatch_once_t once_t = 0;
    dispatch_once(&once_t, ^{
        manager = [[self alloc]init];
    });
    return manager;
}

- (void)getAllAssets:(void (^)(PHFetchResult<PHAsset *> *result))callback{
    long priority = DISPATCH_QUEUE_PRIORITY_DEFAULT;
    dispatch_queue_global_t queue_t = dispatch_get_global_queue(priority, 0);
    dispatch_async(queue_t, ^{
        PHFetchOptions *opt    = [[PHFetchOptions alloc]init];
        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                               ascending:NO];
        opt.sortDescriptors    = @[sort];
        PHFetchResult *result  = [PHAsset fetchAssetsWithOptions:opt];
        !callback ?: callback(result);
    });
}

- (void)imageFromAsset:(PHAsset *)asset
                  size:(CGSize)size
              callback:(void (^)(PHAsset *BBAsset, UIImage *BBImage))callback{
    __weak typeof(self) weak_self = self;
    long priority = DISPATCH_QUEUE_PRIORITY_BACKGROUND;
    dispatch_queue_global_t queue_t = dispatch_get_global_queue(priority, 0);
    dispatch_async(queue_t, ^{
        PHImageRequestOptions *opt = [[PHImageRequestOptions alloc]init];
        opt.resizeMode             = PHImageRequestOptionsResizeModeExact;
        opt.deliveryMode           = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        opt.synchronous            = YES;
        PHCachingImageManager *manager = (PHCachingImageManager *)[PHCachingImageManager defaultManager];
        [manager requestImageForAsset:asset
                           targetSize:size
                          contentMode:PHImageContentModeAspectFit
                              options:opt
                        resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            UIImage *resultImage = [weak_self adjustImage:result];
            dispatch_async(dispatch_get_main_queue(), ^{callback(asset, resultImage);});
        }];
    });
}

/**********************
 按照算法构造出尺寸
 宽高均 <= 1280，图片尺寸大小保持不变
 宽高均 > 1280 取较小值等于1280，较大值等比例压缩
 宽或高 > 1280 取较大值等于1280，较小值等比例压缩
 **********************/
- (CGSize)compressSizeFromAsset:(PHAsset *)asset{
    NSUInteger len = asset.pixelWidth;
    NSUInteger hei = asset.pixelHeight;
    //安全性判断
    if(!len || !hei){return PHImageManagerMaximumSize;}
    
    if(len <= 1280 && hei <= 1280){
        return PHImageManagerMaximumSize;
    }
    
    NSUInteger max = MAX(len, hei);//最大值
    NSUInteger min = MIN(len, hei);//最小值
    if(len >= 1280 && hei >= 1280){
        min = 1280;
        max = 1280.0 * max / min;
        return len > hei ? CGSizeMake(max, hei) : CGSizeMake(min, max);
    }
    
    max = 1280;
    min = min * 1280.0 / max;
    return len > hei ? CGSizeMake(max, min) : CGSizeMake(min, max);
}

- (UIImage *)adjustImage:(UIImage *)aImage{
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage    *img  = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    
    return img;
}

@end
