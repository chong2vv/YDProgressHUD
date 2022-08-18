//
//  SVProgressHUD+YDLottie.m
//  YDProgressHUD
//
//  Created by 王远东 on 2022/8/18.
//  Copyright © 2022 wangyuandong. All rights reserved.
//

#import "SVProgressHUD+YDLottie.h"
#import <objc/runtime.h>

@implementation SVProgressHUD (YDLottie)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self exchangeClassMethod:[self class] method1Sel:@selector(swizzle_sharedView) method2Sel:@selector(sharedView)];
    });
}

+ (SVProgressHUD*)swizzle_sharedView {
    static dispatch_once_t once;
    
    static SVProgressHUD *sharedView;
#if !defined(SV_APP_EXTENSIONS)
    dispatch_once(&once, ^{ sharedView = [[self alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].bounds]; });
#else
    dispatch_once(&once, ^{ sharedView = [[self alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; });
#endif
    return sharedView;
}

+ (void)showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration {
//    [self swizzle_sharedView];
    
//    [[self sharedView] showImage:image status:status duration:duration];
//    [self sharedView].hudView.backgroundColor = [UIColor clearColor];
}
+ (void)showLottieView:(NSString *)jsonPath bgImage:(UIImage *)image status:(NSString *)status {
//    [[self sharedView] showLottieView:jsonPath bgImage:image status:status];
}

+ (void)exchangeClassMethod:(Class)anClass method1Sel:(SEL)method1Sel method2Sel:(SEL)method2Sel {
    Method method1 = class_getClassMethod(anClass, method1Sel);
    Method method2 = class_getClassMethod(anClass, method2Sel);
    method_exchangeImplementations(method1, method2);
}

@end
