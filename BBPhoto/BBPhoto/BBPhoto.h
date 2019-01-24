//
//  BBPhoto.h
//  BBPhoto
//
//  Created by 程肖斌 on 2019/1/24.
//  Copyright © 2019年 ICE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface BBPhoto : NSObject

+ (BBPhoto *)sharedManager;

//获取相册列表
- (void)getAllAssets:(void (^)(PHFetchResult<PHAsset *> *result))callback;

/*
    PHAsset转成image
    asset：转化钱的asset
    size：期望的尺寸，在转化前您期望得到的尺寸，真正转化出来后不一定是这个尺寸，是作为一个参考
    callback：回调
*/
- (void)imageFromAsset:(PHAsset *)asset
                  size:(CGSize)size
              callback:(void (^)(PHAsset *BBAsset, UIImage *BBImage))callback;

/*
 获取压缩图片的期望尺寸，在需要上传等情况时怕图片尺寸过大，需要压缩；
 不好确定尺寸，这个方法提供了一个参考
 */
- (CGSize)compressSizeFromAsset:(PHAsset *)asset;

/*
    调整图片的位置，转出来的image有可能会发生倒转等等情况，这里可以矫正
*/
- (UIImage *)adjustImage:(UIImage *)aImage;

@end

