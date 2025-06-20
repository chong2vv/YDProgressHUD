//
//  YDOverWriteSVProgressHUD.m
//  YDProgressHUD
//
//  Created by 王远东 on 2022/8/19.
//  Copyright © 2022 wangyuandong. All rights reserved.
//

#import "YDOverWriteSVProgressHUD.h"
//
//  SVProgressHUD.h
//  SVProgressHUD, https://github.com/TransitApp/SVProgressHUD
//
//  Copyright (c) 2011-2014 Sam Vermette and contributors. All rights reserved.
//

#if !__has_feature(objc_arc)
#error SVProgressHUD is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#ifndef DEBUG
    #define DEBUG 0
#endif

#import "SVProgressHUD.h"
#import "SVIndefiniteAnimatedView.h"
#import "SVRadialGradientLayer.h"
#import <YYImage/YYImage.h>
#import "YDProgressHUDConfig.h"
#import <Lottie/LOTAnimationView.h>

NSString * const YDSVProgressHUDDidReceiveTouchEventNotification = @"YDSVProgressHUDDidReceiveTouchEventNotification";
NSString * const YDSVProgressHUDDidTouchDownInsideNotification = @"YDSVProgressHUDDidTouchDownInsideNotification";
NSString * const YDSVProgressHUDWillDisappearNotification = @"YDSVProgressHUDWillDisappearNotification";
NSString * const YDSVProgressHUDDidDisappearNotification = @"YDSVProgressHUDDidDisappearNotification";
NSString * const YDSVProgressHUDWillAppearNotification = @"YDSVProgressHUDWillAppearNotification";
NSString * const YDSVProgressHUDDidAppearNotification = @"YDSVProgressHUDDidAppearNotification";

NSString * const YDSVProgressHUDStatusUserInfoKey = @"YDSVProgressHUDStatusUserInfoKey";

static YDProgressHUDStyle SVProgressHUDDefaultStyle;
static SVProgressHUDMaskType SVProgressHUDDefaultMaskType;
static SVProgressHUDAnimationType SVProgressHUDDefaultAnimationType;

static CGFloat SVProgressHUDCornerRadius;
static CGFloat SVProgressHUDRingThickness;
static UIFont *SVProgressHUDFont;
static UIColor *SVProgressHUDForegroundColor;
static UIColor *SVProgressHUDBackgroundColor;
static UIImage *SVProgressHUDInfoImage;
static UIImage *SVProgressHUDSuccessImage;
static UIImage *SVProgressHUDErrorImage;
static UIView *SVProgressHUDExtensionView;
//static BOOL SVProgressHUDNoHideCloseBtn;

static const CGFloat SVProgressHUDRingRadius = 18;
static const CGFloat SVProgressHUDRingNoTextRadius = 24;
static const CGFloat SVProgressHUDParallaxDepthPoints = 10;
static const CGFloat SVProgressHUDUndefinedProgress = -1;

@interface YDOverWriteSVProgressHUD ()

@property (nonatomic, readwrite) SVProgressHUDMaskType maskType;
@property (nonatomic, readwrite) YDProgressHUDStyle style;
@property (nonatomic, strong, readonly) NSTimer *fadeOutTimer;
@property (nonatomic, readonly, getter = isClear) BOOL clear;

@property (nonatomic, strong) UIControl *overlayView;
@property (nonatomic, strong) UIView *hudView;
//@property (nonatomic, strong) UIButton *closeBtn;

@property (nonatomic, strong) UILabel *stringLabel;
@property (nonatomic, strong) YYAnimatedImageView *imageView;

// 扩展lottie相关属性
@property (nonatomic, strong) LOTAnimationView *lottieView;
@property (nonatomic, strong) UIImageView *lottieBGView;

@property (nonatomic, strong) UIView *indefiniteAnimatedView;
@property (nonatomic, strong) SVRadialGradientLayer *backgroundGradientLayer;

@property (nonatomic, readwrite) CGFloat progress;
@property (nonatomic, readwrite) CGFloat dissmissing;
@property (nonatomic, readwrite) NSUInteger activityCount;
@property (nonatomic, strong) CAShapeLayer *backgroundRingLayer;
@property (nonatomic, strong) CAShapeLayer *ringLayer;

@property (nonatomic, readonly) CGFloat visibleKeyboardHeight;
@property (nonatomic, assign) UIOffset offsetFromCenter;

- (void)updateHUDFrame;
- (void)updateMask;
- (void)updateBlurBounds;
- (void)updateMotionEffectForOrientation:(UIInterfaceOrientation)orientation;

- (void)setStatus:(NSString*)string;
- (void)setFadeOutTimer:(NSTimer*)newTimer;

- (void)registerNotifications;
- (NSDictionary*)notificationUserInfo;

- (void)positionHUD:(NSNotification*)notification;
- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle;

- (void)overlayViewDidReceiveTouchEvent:(id)sender forEvent:(UIEvent*)event;

- (void)showProgress:(float)progress status:(NSString*)string;
- (void)showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration;

- (void)dismissWithDelay:(NSTimeInterval)delay;
- (void)dismiss;

- (UIActivityIndicatorView *)createActivityIndicatorView;
- (SVIndefiniteAnimatedView *)createIndefiniteAnimatedView;
- (UIView *)indefiniteAnimatedView;
- (CAShapeLayer*)ringLayer;
- (CAShapeLayer*)backgroundRingLayer;
- (void)cancelRingLayerAnimation;
- (CAShapeLayer*)createRingLayerWithCenter:(CGPoint)center radius:(CGFloat)radius;

- (NSTimeInterval)displayDurationForString:(NSString*)string;
- (UIColor*)foregroundColorForStyle;
- (UIColor*)backgroundColorForStyle;
- (UIImage*)image:(UIImage*)image withTintColor:(UIColor*)color;

@end


@implementation YDOverWriteSVProgressHUD

+ (YDOverWriteSVProgressHUD*)sharedView{
    static dispatch_once_t once;
    
    static YDOverWriteSVProgressHUD *sharedView;
#if !defined(SV_APP_EXTENSIONS)
    dispatch_once(&once, ^{ sharedView = [[self alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.bounds]; });
#else
    dispatch_once(&once, ^{ sharedView = [[self alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; });
#endif
    return sharedView;
}


#pragma mark - Setters

+ (void)setStatus:(NSString*)status{
    [[self sharedView] setStatus:status];
}

+ (void)setDefaultStyle:(YDProgressHUDStyle)style{
    [self sharedView];
    SVProgressHUDDefaultStyle = style;
}

+ (void)setDefaultMaskType:(SVProgressHUDMaskType)maskType{
    [self sharedView];
    SVProgressHUDDefaultMaskType = maskType;
}

+ (void)setDefaultAnimationType:(SVProgressHUDAnimationType)type {
    [self sharedView];
    SVProgressHUDDefaultAnimationType = type;
    // Reset indefiniteAnimatedView so it gets recreated with the new style
    [self sharedView].indefiniteAnimatedView = nil;
}

+ (void)setRingThickness:(CGFloat)width{
    [self sharedView];
    SVProgressHUDRingThickness = width;
}

+ (void)setCornerRadius:(CGFloat)cornerRadius{
    [self sharedView];
    SVProgressHUDCornerRadius = cornerRadius;
}

+ (void)setFont:(UIFont*)font{
    [self sharedView];
    SVProgressHUDFont = font;
}

+ (void)setForegroundColor:(UIColor*)color{
    [self sharedView];
    SVProgressHUDForegroundColor = color;
}

+ (void)setBackgroundColor:(UIColor*)color{
    [self sharedView];
    SVProgressHUDBackgroundColor = color;
}

+ (void)setInfoImage:(UIImage*)image{
    [self sharedView];
    SVProgressHUDInfoImage = image;
}

+ (void)setSuccessImage:(UIImage*)image{
    [self sharedView];
    SVProgressHUDSuccessImage = image;
}

+ (void)setErrorImage:(UIImage*)image{
    [self sharedView];
    SVProgressHUDErrorImage = image;
}

+ (void)setViewForExtension:(UIView*)view{
    [self sharedView];
    SVProgressHUDExtensionView = view;
}

+ (void)setContainerView:(nullable UIView*)containerView {
    [self sharedView];
    [SVProgressHUD setContainerView:containerView];
}



#pragma mark - Show Methods

+ (void)show{
    [self showWithStatus:nil];
}

+ (void)showWithMaskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self show];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showWithStatus:(NSString*)status{
    [self sharedView];
    [self showProgress:SVProgressHUDUndefinedProgress status:status];
}

+ (void)showWithStatus:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showWithStatus:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showProgress:(float)progress{
    [self showProgress:progress status:nil];
}

+ (void)showProgress:(float)progress maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showProgress:progress];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showProgress:(float)progress status:(NSString*)status{
    [[self sharedView] showProgress:progress status:status];
}

+ (void)showProgress:(float)progress status:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showProgress:progress status:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

#pragma mark - Show, then automatically dismiss methods

+ (void)showInfoWithStatus:(NSString*)status{
    [self sharedView];
    [self showImage:SVProgressHUDInfoImage status:status];
}

+ (void)showInfoWithStatus:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showInfoWithStatus:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showSuccessWithStatus:(NSString*)status{
    [self sharedView];
    [self showImage:SVProgressHUDSuccessImage status:status];
}

+ (void)showSuccessWithStatus:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showSuccessWithStatus:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showErrorWithStatus:(NSString*)status{
    [self sharedView];
    [self showImage:SVProgressHUDErrorImage status:status];
}

+ (void)showErrorWithStatus:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showErrorWithStatus:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}

+ (void)showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration {
    [[self sharedView] showImage:image status:status duration:duration];
//    [self sharedView].hudView.backgroundColor = [UIColor clearColor];
}
+ (void)showLottieView:(NSString *)jsonPath bgImage:(UIImage *)image status:(NSString *)status {
    [[self sharedView] showLottieView:jsonPath bgImage:image status:status];
}

+ (void)showImage:(UIImage*)image status:(NSString*)status{
    NSTimeInterval displayInterval = [[self sharedView] displayDurationForString:status];
    [[self sharedView] showImage:image status:status duration:displayInterval];
}

+ (void)showImage:(UIImage*)image status:(NSString*)status maskType:(SVProgressHUDMaskType)maskType{
    [self setDefaultMaskType:maskType];
    [self showImage:image status:status];
    [self setDefaultMaskType:SVProgressHUDMaskTypeNone];
}


#pragma mark - Dismiss Methods

+ (void)popActivity{
    if([self sharedView].activityCount > 0){
        [self sharedView].activityCount--;
    }
    if([self sharedView].activityCount == 0){
        [[self sharedView] dismiss];
    }
}

+ (void)dismissWithDelay:(NSTimeInterval)delay{
    if([self isVisible]){
        [[self sharedView] dismissWithDelay:delay];
    }
}

+ (void)dismiss{
    [self dismissWithDelay:0];
}


#pragma mark - Offset

+ (void)setOffsetFromCenter:(UIOffset)offset{
    [self sharedView].offsetFromCenter = offset;
}

+ (void)resetOffsetFromCenter{
    [self setOffsetFromCenter:UIOffsetZero];
}


#pragma mark - Instance Methods

- (instancetype)initWithFrame:(CGRect)frame{
    if((self = [super initWithFrame:frame])){
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.alpha = 0.0f;
        self.activityCount = 0;
        
        // add accessibility support
        self.accessibilityIdentifier = @"SVProgressHUD";
        self.accessibilityLabel = @"SVProgressHUD";
        self.isAccessibilityElement = YES;
        
        // Customize properties
        SVProgressHUDDefaultStyle = YDProgressHUDStyleLight;
        SVProgressHUDDefaultMaskType = SVProgressHUDMaskTypeNone;
        SVProgressHUDDefaultAnimationType = SVProgressHUDAnimationTypeFlat;

        SVProgressHUDRingThickness = 2;
        SVProgressHUDCornerRadius = 14;
        SVProgressHUDForegroundColor = [UIColor blackColor];
        SVProgressHUDBackgroundColor = [UIColor whiteColor];
        
        if([UIFont respondsToSelector:@selector(preferredFontForTextStyle:)]){
            SVProgressHUDFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        } else{
            SVProgressHUDFont = [UIFont systemFontOfSize:14.0f];
        }
        
        UIImage* infoImage = [YDProgressHUDConfig infoImage];
        UIImage* successImage = [YDProgressHUDConfig successImage];
        UIImage* errorImage = [YDProgressHUDConfig errorImage];

        if([[UIImage class] instancesRespondToSelector:@selector(imageWithRenderingMode:)]){
            SVProgressHUDInfoImage = [infoImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            SVProgressHUDSuccessImage = [successImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            SVProgressHUDErrorImage = [errorImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else{
            SVProgressHUDInfoImage = infoImage;
            SVProgressHUDSuccessImage = successImage;
            SVProgressHUDErrorImage = errorImage;
        }
    }
    
    return self;
}

- (void)updateHUDFrame{
    CGFloat hudWidth = [YDProgressHUDConfig hudBackgroundSize].width;
    CGFloat hudHeight = [YDProgressHUDConfig hudBackgroundSize].height;
    
    // 因为lottie动画需要背景图, 且背景图有阴影, 所以当有背景图的时候需要hudview的size大一点
//    if (self.lottieBGView) {
//        hudWidth = 120.0f;
//        hudHeight = 120.0f;
//    }
    CGFloat stringHeightBuffer = 20.0f;
    CGFloat stringAndContentHeightBuffer = 80.0f;
    CGRect labelRect = CGRectZero;
    
    // Check if an image or progress ring is displayed
    BOOL imageUsed = (self.imageView.image) || (self.imageView.hidden);
    BOOL progressUsed = (self.progress != SVProgressHUDUndefinedProgress) && (self.progress >= 0.0f);
    
    // Calculate and apply sizes
    NSString *string = self.stringLabel.text;
    if(string){
        CGSize constraintSize = CGSizeMake(200.0f, 300.0f);
        CGRect stringRect;
        if([string respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]){
            stringRect = [string boundingRectWithSize:constraintSize
                                              options:(NSStringDrawingOptions)(NSStringDrawingUsesFontLeading|NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin)
                                           attributes:@{NSFontAttributeName: self.stringLabel.font}
                                              context:NULL];
        } else{
            CGSize stringSize;
            if([string respondsToSelector:@selector(sizeWithAttributes:)]){
                stringSize = [string sizeWithAttributes:@{NSFontAttributeName:[UIFont fontWithName:self.stringLabel.font.fontName size:self.stringLabel.font.pointSize]}];
            } else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
                stringSize = [string sizeWithFont:self.stringLabel.font constrainedToSize:CGSizeMake(200.0f, 300.0f)];
#pragma clang diagnostic pop
            }
            stringRect = CGRectMake(0.0f, 0.0f, stringSize.width, stringSize.height);
        }

        CGFloat stringWidth = stringRect.size.width;
        CGFloat stringHeight = ceilf(CGRectGetHeight(stringRect));
        
        if(imageUsed || progressUsed){
            hudHeight = stringAndContentHeightBuffer + stringHeight;
        } else{
            hudHeight = stringHeightBuffer + stringHeight;
        }
        if(stringWidth > hudWidth){
            hudWidth = ceilf(stringWidth/2)*2;
        }
        CGFloat labelRectY = (imageUsed || progressUsed) ? 68.0f : 9.0f;
        if(hudHeight > 100.0f){
            labelRect = CGRectMake(12.0f, labelRectY, hudWidth, stringHeight);
            hudWidth += 24.0f;
        } else{
            labelRect = CGRectMake(12.0f, labelRectY, hudWidth, stringHeight);
            hudWidth += 24.0f;
        }
    }
    // Update values on subviews
    self.hudView.bounds = CGRectMake(0.0f, 0.0f, hudWidth, hudHeight);
    if ([YDProgressHUDConfig addBlurEffect]) {
        [self updateBlurBounds];
    }
    
    // 添加lottie动画相关视图的frame
    if (self.lottieBGView) {
        self.lottieBGView.frame = self.hudView.bounds;
    }
    if (self.lottieView) {
        self.lottieView.frame = self.lottieBGView?self.lottieBGView.bounds:self.hudView.bounds;
    }
    
    if(string){
        self.imageView.center = CGPointMake(CGRectGetWidth(self.hudView.bounds)/2, self.imageView.frame.size.height / 2.f + 8.f);
    } else{
           self.imageView.center = CGPointMake(CGRectGetWidth(self.hudView.bounds)/2, CGRectGetHeight(self.hudView.bounds)/2);
    }

    self.stringLabel.hidden = NO;
    self.stringLabel.frame = labelRect;
    
//    self.closeBtn.bounds = CGRectMake(0, 0, 30, 30);
//    self.closeBtn.hidden = !SVProgressHUDNoHideCloseBtn;
    
    // Animate value update
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    if(string) {
        if(SVProgressHUDDefaultAnimationType == SVProgressHUDAnimationTypeFlat) {
            SVIndefiniteAnimatedView *indefiniteAnimationView = (SVIndefiniteAnimatedView *)self.indefiniteAnimatedView;
            indefiniteAnimationView.radius = SVProgressHUDRingRadius;
            [indefiniteAnimationView sizeToFit];
        }
        
        CGPoint center = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), 36.f);
        self.indefiniteAnimatedView.center = center;
        
        if(self.progress != SVProgressHUDUndefinedProgress){
            self.backgroundRingLayer.position = self.ringLayer.position = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), 36.f);
        }
    } else {
        if(SVProgressHUDDefaultAnimationType == SVProgressHUDAnimationTypeFlat) {
            SVIndefiniteAnimatedView *indefiniteAnimationView = (SVIndefiniteAnimatedView *)self.indefiniteAnimatedView;
            indefiniteAnimationView.radius = SVProgressHUDRingNoTextRadius;
            [indefiniteAnimationView sizeToFit];
        }
        
        CGPoint center = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), CGRectGetHeight(self.hudView.bounds)/2);
        self.indefiniteAnimatedView.center = center;
        
        if(self.progress != SVProgressHUDUndefinedProgress){
            self.backgroundRingLayer.position = self.ringLayer.position = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), CGRectGetHeight(self.hudView.bounds)/2);
        }
    }
    
    [CATransaction commit];
}

- (void)updateMask{
    if(self.backgroundGradientLayer){
        [self.backgroundGradientLayer removeFromSuperlayer];
        self.backgroundGradientLayer = nil;
    }
    switch (self.maskType){
        case SVProgressHUDMaskTypeBlack:{
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
            break;
        }
            
        case SVProgressHUDMaskTypeGradient:{
            self.backgroundColor = [UIColor clearColor];
            self.backgroundGradientLayer = [SVRadialGradientLayer layer];
            self.backgroundGradientLayer.frame = self.bounds;
            CGPoint gradientCenter = self.center;
            gradientCenter.y = (self.bounds.size.height - self.visibleKeyboardHeight) / 2;
            self.backgroundGradientLayer.gradientCenter = gradientCenter;
            [self.backgroundGradientLayer setNeedsDisplay];
            
            [self.layer addSublayer:self.backgroundGradientLayer];
            break;
        }
        default:
            self.backgroundColor = [UIColor clearColor];
            break;
    }
}

- (void)updateBlurBounds{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if(NSClassFromString(@"UIBlurEffect")){
        // Remove background color, else the effect would not work
        self.hudView.backgroundColor = [UIColor clearColor];
        
        
        // Remove any old instances of UIVisualEffectViews
        for (UIView *subview in self.hudView.subviews){
            if([subview isKindOfClass:[UIVisualEffectView class]]){
                [subview removeFromSuperview];
            }
        }
        
        if(SVProgressHUDBackgroundColor != [UIColor clearColor]){
            // Create blur effect
            UIBlurEffectStyle blurEffectStyle = self.style == YDProgressHUDStyleDark ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurEffectStyle];
            UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurEffectView.autoresizingMask = self.hudView.autoresizingMask;
            blurEffectView.frame = self.hudView.bounds;
            
            // Add vibrancy to the blur effect to make it more vivid
            UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
            UIVisualEffectView *vibrancyEffectView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
            vibrancyEffectView.autoresizingMask = blurEffectView.autoresizingMask;
            vibrancyEffectView.bounds = blurEffectView.bounds;
            [blurEffectView.contentView addSubview:vibrancyEffectView];
            
            [self.hudView insertSubview:blurEffectView atIndex:0];
        }
    }
#endif
}

- (void)updateMotionEffectForOrientation:(UIInterfaceOrientation)orientation{
    if([_hudView respondsToSelector:@selector(addMotionEffect:)]){
        UIInterpolatingMotionEffectType motionEffectType = UIInterfaceOrientationIsPortrait(orientation) ? UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis : UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis;
        UIInterpolatingMotionEffect *effectX = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:motionEffectType];
        effectX.minimumRelativeValue = @(-SVProgressHUDParallaxDepthPoints);
        effectX.maximumRelativeValue = @(SVProgressHUDParallaxDepthPoints);
        
        motionEffectType = UIInterfaceOrientationIsPortrait(orientation) ? UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis : UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis;
        UIInterpolatingMotionEffect *effectY = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:motionEffectType];
        effectY.minimumRelativeValue = @(-SVProgressHUDParallaxDepthPoints);
        effectY.maximumRelativeValue = @(SVProgressHUDParallaxDepthPoints);
        
        UIMotionEffectGroup *effectGroup = [[UIMotionEffectGroup alloc] init];
        effectGroup.motionEffects = @[effectX, effectY];
        
        // Update motion effects
        self.hudView.motionEffects = @[];
        if (!self.defaultMotionEffectsEnabled) {
            [self.hudView addMotionEffect:effectGroup];
        }
    }
}

- (BOOL)defaultMotionEffectsEnabled {
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"12.0") && DEBUG) {
       return YES;
    }
    return NO;

}

- (void)setStatus:(NSString*)string{
    self.stringLabel.text = string;
    [self updateHUDFrame];
}

- (void)setFadeOutTimer:(NSTimer*)newTimer{
    if(_fadeOutTimer){
        [_fadeOutTimer invalidate];
        _fadeOutTimer = nil;
    }
    if(newTimer){
        _fadeOutTimer = newTimer;
    }
}


#pragma mark - Notifications and their handling

- (void)registerNotifications{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}

- (NSDictionary*)notificationUserInfo{
    return (self.stringLabel.text ? @{YDSVProgressHUDStatusUserInfoKey : self.stringLabel.text} : nil);
}

- (void)positionHUD:(NSNotification*)notification{
    CGFloat keyboardHeight = 0.0f;
    double animationDuration = 0.0;
    
#if !defined(SV_APP_EXTENSIONS)
    self.frame = [UIApplication sharedApplication].keyWindow.bounds;
    UIInterfaceOrientation orientation = UIApplication.sharedApplication.statusBarOrientation;
#else
    self.frame = UIScreen.mainScreen.bounds;
    UIInterfaceOrientation orientation = CGRectGetWidth(self.frame) > CGRectGetHeight(self.frame) ? UIInterfaceOrientationLandscapeLeft : UIInterfaceOrientationPortrait;
#endif
    
    // no transforms applied to window in iOS 8, but only if compiled with iOS 8 sdk as base sdk, otherwise system supports old rotation logic.
    BOOL ignoreOrientation = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]){
        ignoreOrientation = YES;
    }
#endif
    
    // Get keyboardHeight in regards to current state
    if(notification){
        NSDictionary* keyboardInfo = [notification userInfo];
        CGRect keyboardFrame = [keyboardInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        animationDuration = [keyboardInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        
        if(notification.name == UIKeyboardWillShowNotification || notification.name == UIKeyboardDidShowNotification){
            if(ignoreOrientation || UIInterfaceOrientationIsPortrait(orientation)){
                keyboardHeight = CGRectGetHeight(keyboardFrame);
            } else{
                keyboardHeight = CGRectGetWidth(keyboardFrame);
            }
        }
    } else{
        keyboardHeight = self.visibleKeyboardHeight;
    }
    
    // Get the currently active frame of the display (depends on orientation)
    CGRect orientationFrame = self.bounds;
#if !defined(SV_APP_EXTENSIONS)
    CGRect statusBarFrame = UIApplication.sharedApplication.statusBarFrame;
#else
    CGRect statusBarFrame = CGRectZero;
#endif
    
    if(!ignoreOrientation && UIInterfaceOrientationIsLandscape(orientation)){
        float temp = CGRectGetWidth(orientationFrame);
        orientationFrame.size.width = CGRectGetHeight(orientationFrame);
        orientationFrame.size.height = temp;
        
        temp = CGRectGetWidth(statusBarFrame);
        statusBarFrame.size.width = CGRectGetHeight(statusBarFrame);
        statusBarFrame.size.height = temp;
    }
    
    // Update the motion effects in regards to orientation
    [self updateMotionEffectForOrientation:orientation];
    
    // Calculate available height for display
    CGFloat activeHeight = CGRectGetHeight(orientationFrame);
    if(keyboardHeight > 0){
        activeHeight += CGRectGetHeight(statusBarFrame)*2;
    }
    activeHeight -= keyboardHeight;
    
    CGFloat posX = CGRectGetWidth(orientationFrame)/2.0f;
    CGFloat posY = floorf(activeHeight*0.45f);

    CGPoint newCenter;
    CGFloat rotateAngle;
    
    // Update posX and posY in regards to orientation
    if(ignoreOrientation){
        rotateAngle = 0.0;
        newCenter = CGPointMake(posX, posY);
    } else{
        switch (orientation){
            case UIInterfaceOrientationPortraitUpsideDown:
                rotateAngle = (CGFloat) M_PI;
                newCenter = CGPointMake(posX, CGRectGetHeight(orientationFrame)-posY);
                break;
            case UIInterfaceOrientationLandscapeLeft:
                rotateAngle = (CGFloat) (-M_PI/2.0f);
                newCenter = CGPointMake(posY, posX);
                break;
            case UIInterfaceOrientationLandscapeRight:
                rotateAngle = (CGFloat) (M_PI/2.0f);
                newCenter = CGPointMake(CGRectGetHeight(orientationFrame)-posY, posX);
                break;
            default: // Same as UIInterfaceOrientationPortrait
                rotateAngle = 0.0f;
                newCenter = CGPointMake(posX, posY);
                break;
        }
    }
    
    if(notification){
        // Animate update if notification was present
        [UIView animateWithDuration:animationDuration
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             [self moveToPoint:newCenter rotateAngle:rotateAngle];
                             [self.hudView setNeedsDisplay];
                         } completion:NULL];
    } else{
        [self moveToPoint:newCenter rotateAngle:rotateAngle];
        [self.hudView setNeedsDisplay];
    }
    
}

- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle{
    self.hudView.transform = CGAffineTransformMakeRotation(angle);
    self.hudView.center = CGPointMake(newCenter.x + self.offsetFromCenter.horizontal, newCenter.y + self.offsetFromCenter.vertical);
//    self.closeBtn.center = CGPointMake(CGRectGetMaxX(self.hudView.frame),CGRectGetMinY(self.hudView.frame));
}


#pragma mark - Event handling

- (void)overlayViewDidReceiveTouchEvent:(id)sender forEvent:(UIEvent*)event{
    [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidReceiveTouchEventNotification object:event];
    
    UITouch *touch = event.allTouches.anyObject;
    CGPoint touchLocation = [touch locationInView:self];
    
    if(CGRectContainsPoint(self.hudView.frame, touchLocation)){
        [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidTouchDownInsideNotification object:event];
        return;
    }
    
//    if(CGRectContainsPoint(self.closeBtn.frame, touchLocation)){
//        [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidTouchDownInsideNotification object:event];
//    }
}

- (void)cancelAction:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidTouchDownInsideNotification object:nil];
}

#pragma mark - Master show/dismiss methods

- (void)showProgress:(float)progress status:(NSString*)string{
    if(!self.overlayView.superview){
#if !defined(SV_APP_EXTENSIONS)
        NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
        for (UIWindow *window in frontToBackWindows){
            BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
            BOOL windowIsVisible = !window.hidden && window.alpha > 0;
            BOOL windowLevelNormal = window.windowLevel == UIWindowLevelNormal;
            
            BOOL windowVc = window.rootViewController != nil;
            if(windowOnMainScreen && windowIsVisible && windowLevelNormal && windowVc){
                [window addSubview:self.overlayView];
                break;
            }
        }
#else
        if(SVProgressHUDExtensionView){
            [SVProgressHUDExtensionView addSubview:self.overlayView];
        }
#endif
    } else{
        // Ensure that overlay will be exactly on top of rootViewController (which may be changed during runtime).
        [self.overlayView.superview bringSubviewToFront:self.overlayView];
    }
    
    if(!self.superview){
        [self.overlayView addSubview:self];
    }
    
    if(self.fadeOutTimer){
        self.activityCount = 0;
    }
    self.fadeOutTimer = nil;
    self.imageView.hidden = YES;
    self.maskType = SVProgressHUDDefaultMaskType;
    self.style = SVProgressHUDDefaultStyle;
    self.progress = progress;
    
    self.stringLabel.text = string;
    [self updateHUDFrame];
    [self updateMask];
    
    if(progress >= 0){
        self.imageView.image = nil;
        self.imageView.hidden = NO;
        
        [self.indefiniteAnimatedView removeFromSuperview];
        if([self.indefiniteAnimatedView respondsToSelector:@selector(stopAnimating)]) {
            [(id)self.indefiniteAnimatedView stopAnimating];
        }
        
        self.ringLayer.strokeEnd = progress;
        
        if(progress == 0){
            self.activityCount++;
        }
    } else{
        self.activityCount++;
        [self cancelRingLayerAnimation];
        
        [self.hudView addSubview:self.indefiniteAnimatedView];
        if([self.indefiniteAnimatedView respondsToSelector:@selector(startAnimating)]) {
            [(id)self.indefiniteAnimatedView startAnimating];
        }
    }
    
    if(self.maskType != SVProgressHUDMaskTypeNone){
        self.overlayView.userInteractionEnabled = YES;
        self.accessibilityLabel = string;
        self.isAccessibilityElement = YES;
    } else{
        self.overlayView.userInteractionEnabled = NO;
        self.hudView.accessibilityLabel = string;
        self.hudView.isAccessibilityElement = YES;
    }
    
    self.overlayView.hidden = NO;
    self.overlayView.backgroundColor = [UIColor clearColor];
    [self positionHUD:nil];
    
    // Appear
    if(self.alpha != 1 || self.hudView.alpha != 1){
        NSDictionary *userInfo = [self notificationUserInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDWillAppearNotification
                                                            object:nil
                                                          userInfo:userInfo];
        
        [self registerNotifications];
        self.hudView.transform = CGAffineTransformScale(self.hudView.transform, 1.3, 1.3);
        
        if(self.isClear){
            self.alpha = 1;
            self.hudView.alpha = 0;
        }
        
        __weak YDOverWriteSVProgressHUD *weakSelf = self;
        [UIView animateWithDuration:0.15
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             __strong YDOverWriteSVProgressHUD *strongSelf = weakSelf;
                             if(strongSelf){
                                 strongSelf.hudView.transform = CGAffineTransformScale(strongSelf.hudView.transform, 1/1.3f, 1/1.3f);
                                 
                                 if(strongSelf.isClear){ // handle iOS 7 and 8 UIToolbar which not answers well to hierarchy opacity change
                                     strongSelf.hudView.alpha = 1;
                                 } else{
                                     strongSelf.alpha = 1;
                                 }
                             }
                         }
                         completion:^(BOOL finished){
                             [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidAppearNotification
                                                                                 object:nil
                                                                               userInfo:userInfo];
                             UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
                             UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, string);
                         }];
        
        [self setNeedsDisplay];
    }
}
- (void)showLottieView:(NSString *)jsonPath bgImage:(UIImage *)image status:(NSString *)status {
    if (self.dissmissing) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showLottieView:jsonPath bgImage:image status:status];
        });
        return;
    }
    self.stringLabel.text = nil;
    // 动画背景图
    UIImageView *lottieBgview = [[UIImageView alloc] initWithImage:image];
    [self.hudView addSubview:lottieBgview];
    self.lottieBGView = lottieBgview;
    LOTAnimationView * animateView = [LOTAnimationView animationWithFilePath:jsonPath];
    [self.lottieBGView addSubview:animateView];
    self.lottieView = animateView;
    self.lottieView.loopAnimation = YES;
    [self.lottieView play];
    self.progress = SVProgressHUDUndefinedProgress;
    [self cancelRingLayerAnimation];
    
    if(![self.class isVisible]){
        [self.class show];
    }
    
    self.maskType = SVProgressHUDDefaultMaskType;
    self.style = SVProgressHUDDefaultStyle;

    [self updateHUDFrame];
    [self.indefiniteAnimatedView removeFromSuperview];
    if([self.indefiniteAnimatedView respondsToSelector:@selector(stopAnimating)]) {
        [(id)self.indefiniteAnimatedView stopAnimating];
    }
    
    if(self.maskType != SVProgressHUDMaskTypeNone){
        self.overlayView.userInteractionEnabled = YES;
        self.isAccessibilityElement = YES;
    } else{
        self.overlayView.userInteractionEnabled = NO;
        self.hudView.isAccessibilityElement = YES;
    }
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    
//    self.fadeOutTimer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
//    [[NSRunLoop mainRunLoop] addTimer:self.fadeOutTimer forMode:NSRunLoopCommonModes];
}
- (void)showImage:(UIImage*)image status:(NSString*)string duration:(NSTimeInterval)duration{
    if (self.dissmissing) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showImage:image status:string duration:duration];
        });
        return;
    }
    
    self.progress = SVProgressHUDUndefinedProgress;
    [self cancelRingLayerAnimation];
    
    if(![self.class isVisible]){
        [self.class show];
    }
    
    UIColor *tintColor = self.foregroundColorForStyle;
    if([self.imageView respondsToSelector:@selector(setTintColor:)]){
        self.imageView.tintColor = tintColor;
    } else{
        image = [self image:image withTintColor:tintColor];
    }
    
    self.imageView.image = image;
    self.imageView.hidden = NO;
    self.maskType = SVProgressHUDDefaultMaskType;
    self.style = SVProgressHUDDefaultStyle;
    
    self.stringLabel.text = string;
    [self updateHUDFrame];
    [self.indefiniteAnimatedView removeFromSuperview];
    if([self.indefiniteAnimatedView respondsToSelector:@selector(stopAnimating)]) {
        [(id)self.indefiniteAnimatedView stopAnimating];
    }
    
    if(self.maskType != SVProgressHUDMaskTypeNone){
        self.overlayView.userInteractionEnabled = YES;
        self.accessibilityLabel = string;
        self.isAccessibilityElement = YES;
    } else{
        self.overlayView.userInteractionEnabled = NO;
        self.hudView.accessibilityLabel = string;
        self.hudView.isAccessibilityElement = YES;
    }
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, string);
    
    self.fadeOutTimer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.fadeOutTimer forMode:NSRunLoopCommonModes];
}

- (void)dismissWithDelay:(NSTimeInterval)delay{
    NSDictionary *userInfo = [self notificationUserInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDWillDisappearNotification
                                                        object:nil
                                                      userInfo:userInfo];
    
    self.activityCount = 0;
    self.dissmissing = YES;
    __weak YDOverWriteSVProgressHUD *weakSelf = self;
    [UIView animateWithDuration:0.15
                          delay:delay
                        options:(UIViewAnimationOptions) (UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         __strong YDOverWriteSVProgressHUD *strongSelf = weakSelf;
                         if(strongSelf){
                             strongSelf.hudView.transform = CGAffineTransformScale(self.hudView.transform, 0.8f, 0.8f);
                             if(strongSelf.isClear){ // handle iOS 7 UIToolbar not answer well to hierarchy opacity change
                                 strongSelf.hudView.alpha = 0.0f;
//                                 strongSelf.closeBtn.alpha = 0.0f;
                             } else{
                                 strongSelf.alpha = 0.0f;
                             }
                         }
                     }
                     completion:^(BOOL finished){
                         __strong YDOverWriteSVProgressHUD *strongSelf = weakSelf;
                         if(strongSelf){
                             if(strongSelf.alpha == 0.0f || strongSelf.hudView.alpha == 0.0f){
                                 strongSelf.alpha = 0.0f;
                                 strongSelf.hudView.alpha = 0.0f;
//                                 strongSelf.closeBtn.alpha = 0.0f;
                                 
                                 [[NSNotificationCenter defaultCenter] removeObserver:strongSelf];
                                 [strongSelf cancelRingLayerAnimation];
                                 for (UIView * subView in strongSelf.hudView.subviews) {
                                     [subView removeFromSuperview];
                                 }
                                 self.lottieView = nil;
                                 self.lottieBGView = nil;
                                 [strongSelf.hudView removeFromSuperview];
                                 strongSelf.hudView = nil;
                                 
//                                 [_closeBtn removeFromSuperview];
//                                 _closeBtn = nil;
                                 
                                 [strongSelf.overlayView removeFromSuperview];
                                 strongSelf.overlayView = nil;
                                 
                                 [strongSelf.indefiniteAnimatedView removeFromSuperview];
                                 strongSelf.indefiniteAnimatedView = nil;
                                 
                                 UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
                                 
                                 [[NSNotificationCenter defaultCenter] postNotificationName:YDSVProgressHUDDidDisappearNotification
                                                                                     object:nil
                                                                                   userInfo:userInfo];
                                 
                                 // Tell the rootViewController to update the StatusBar appearance
#if !defined(SV_APP_EXTENSIONS)
                                 UIViewController *rootController = [[UIApplication sharedApplication] keyWindow].rootViewController;
                                 if([rootController respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]){
                                     [rootController setNeedsStatusBarAppearanceUpdate];
                                 }
#endif
                                 // uncomment to make sure UIWindow is gone from app.windows
                                 //NSLog(@"%@", [UIApplication sharedApplication].windows);
                                 //NSLog(@"keyWindow = %@", [UIApplication sharedApplication].keyWindow);
                             }
                         }
                         
                         self.dissmissing = NO;
                     }];
}

- (void)dismiss
{
    [self dismissWithDelay:0];
}


#pragma mark - Ring progress animation

- (UIActivityIndicatorView *)createActivityIndicatorView{
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicatorView.color = self.foregroundColorForStyle;
    [activityIndicatorView sizeToFit];
    return activityIndicatorView;
}

- (SVIndefiniteAnimatedView *)createIndefiniteAnimatedView{
    SVIndefiniteAnimatedView *indefiniteAnimatedView = [[SVIndefiniteAnimatedView alloc] initWithFrame:CGRectZero];
    indefiniteAnimatedView.strokeColor = self.foregroundColorForStyle;
    indefiniteAnimatedView.radius = self.stringLabel.text ? SVProgressHUDRingRadius : SVProgressHUDRingNoTextRadius;
    indefiniteAnimatedView.strokeThickness = SVProgressHUDRingThickness;
    [indefiniteAnimatedView sizeToFit];
    return indefiniteAnimatedView;
}

- (UIView *)indefiniteAnimatedView{
    if(_indefiniteAnimatedView == nil){
        _indefiniteAnimatedView = (SVProgressHUDDefaultAnimationType == SVProgressHUDAnimationTypeFlat) ? [self createIndefiniteAnimatedView] : [self createActivityIndicatorView];
    }
    return _indefiniteAnimatedView;
}

- (CAShapeLayer*)ringLayer{
    if(!_ringLayer){
        CGPoint center = CGPointMake(CGRectGetWidth(_hudView.frame)/2, CGRectGetHeight(_hudView.frame)/2);
        _ringLayer = [self createRingLayerWithCenter:center radius:SVProgressHUDRingRadius];
        [self.hudView.layer addSublayer:_ringLayer];
    }
    _ringLayer.strokeColor = self.foregroundColorForStyle.CGColor;
    _ringLayer.lineWidth = SVProgressHUDRingThickness;
    
    return _ringLayer;
}

- (CAShapeLayer*)backgroundRingLayer{
    if(!_backgroundRingLayer){
        CGPoint center = CGPointMake(CGRectGetWidth(_hudView.frame)/2, CGRectGetHeight(_hudView.frame)/2);
        _backgroundRingLayer = [self createRingLayerWithCenter:center radius:SVProgressHUDRingRadius];
        _backgroundRingLayer.strokeEnd = 1;
        [self.hudView.layer addSublayer:_backgroundRingLayer];
    }
    _ringLayer.strokeColor = [self.foregroundColorForStyle colorWithAlphaComponent:0.1f].CGColor;
    _ringLayer.lineWidth = SVProgressHUDRingThickness;
    
    return _backgroundRingLayer;
}

- (void)cancelRingLayerAnimation{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_hudView.layer removeAllAnimations];
    
    _ringLayer.strokeEnd = 0.0f;
    if(_ringLayer.superlayer){
        [_ringLayer removeFromSuperlayer];
    }
    _ringLayer = nil;
    
    if(_backgroundRingLayer.superlayer){
        [_backgroundRingLayer removeFromSuperlayer];
    }
    _backgroundRingLayer = nil;
    
    [CATransaction commit];
}

- (CAShapeLayer*)createRingLayerWithCenter:(CGPoint)center radius:(CGFloat)radius{
    UIBezierPath* smoothedPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(radius, radius) radius:radius startAngle:(CGFloat) -M_PI_2 endAngle:(CGFloat) (M_PI + M_PI_2) clockwise:YES];
    
    CAShapeLayer *slice = [CAShapeLayer layer];
    slice.contentsScale = [[UIScreen mainScreen] scale];
    slice.frame = CGRectMake(center.x-radius, center.y-radius, radius*2, radius*2);
    slice.fillColor = [UIColor clearColor].CGColor;
    slice.lineCap = kCALineCapRound;
    slice.lineJoin = kCALineJoinBevel;
    slice.path = smoothedPath.CGPath;
    
    return slice;
}


#pragma mark - Utilities

+ (BOOL)isVisible{
    return ([self sharedView].alpha == 1);
}


#pragma mark - Getters

- (NSTimeInterval)displayDurationForString:(NSString*)string{
    return MIN((float)string.length*0.06 + 0.5, 5.0);
}

- (UIColor*)foregroundColorForStyle{
    if(self.style == YDProgressHUDStyleLight){
        return [UIColor blackColor];
    } else if(self.style == YDProgressHUDStyleDark){
        return [UIColor whiteColor];
    } else{
        return SVProgressHUDForegroundColor;
    }
}

- (UIColor*)backgroundColorForStyle{
    if (self.style == YDProgressHUDStyleToast) {
        return [YDProgressHUDConfig hudBackgroundColor];
    } else if (self.style == YDProgressHUDStyleLoading){
        return [YDProgressHUDConfig hudLoadingBackgroundColor];
    } else if(self.style == YDProgressHUDStyleLight){
        return [UIColor whiteColor];
    } else if(self.style == YDProgressHUDStyleDark){
        return [UIColor blackColor];
    } else{
        return SVProgressHUDBackgroundColor;
    }
}

- (UIImage*)image:(UIImage*)image withTintColor:(UIColor*)color{
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [image drawInRect:rect];
    CGContextSetFillColorWithColor(c, [color CGColor]);
    CGContextSetBlendMode(c, kCGBlendModeSourceAtop);
    CGContextFillRect(c, rect);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return tintedImage;
}

- (BOOL)isClear{ // used for iOS 7 and above
    return (self.maskType == SVProgressHUDMaskTypeClear || self.maskType == SVProgressHUDMaskTypeNone);
}

- (UIControl*)overlayView{
    if(!_overlayView){
#if !defined(SV_APP_EXTENSIONS)
        CGRect windowBounds = [UIApplication sharedApplication].keyWindow.bounds;
        _overlayView = [[UIControl alloc] initWithFrame:windowBounds];
#else
        _overlayView = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
#endif
        _overlayView = [[UIControl alloc] initWithFrame:windowBounds];
        _overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _overlayView.backgroundColor = [UIColor clearColor];
        [_overlayView addTarget:self action:@selector(overlayViewDidReceiveTouchEvent:forEvent:) forControlEvents:UIControlEventTouchDown];
    }
    return _overlayView;
}

- (UIView*)hudView{
    if(!_hudView){
        _hudView = [[UIView alloc] initWithFrame:CGRectZero];
        _hudView.layer.cornerRadius = SVProgressHUDCornerRadius;
        _hudView.layer.masksToBounds = YES;
        _hudView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    }

    if (_lottieView) {
        _hudView.backgroundColor = [UIColor clearColor];
    } else {
        _hudView.backgroundColor = self.backgroundColorForStyle;
    }
    
    if(!_hudView.superview){
        [self addSubview:_hudView];
//        [self bringSubviewToFront:_hudView];
    }
    return _hudView;
}

- (UILabel*)stringLabel{
    if(!_stringLabel){
        _stringLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _stringLabel.backgroundColor = [UIColor clearColor];
        _stringLabel.adjustsFontSizeToFitWidth = YES;
        _stringLabel.textAlignment = NSTextAlignmentCenter;
        _stringLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        _stringLabel.numberOfLines = 0;
    }
    if ([YDProgressHUDConfig foregroundColor]) {
        _stringLabel.textColor = [YDProgressHUDConfig foregroundColor];
    } else {
        _stringLabel.textColor = self.foregroundColorForStyle;
    }
    _stringLabel.font = SVProgressHUDFont;
    
    if(!_stringLabel.superview){
        [self.hudView addSubview:_stringLabel];
    }
    return _stringLabel;
}

- (YYAnimatedImageView*)imageView{
    if(!_imageView){
        CGSize imageViewSize = [YDProgressHUDConfig gifImageViewSize];
        if (imageViewSize.width > 0) {
            _imageView = [[YYAnimatedImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, imageViewSize.width, imageViewSize.height)];
        } else {
            _imageView = [[YYAnimatedImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
        }
        
    }
    if(!_imageView.superview){
        [self.hudView addSubview:_imageView];
    }
    return _imageView;
}

- (CGFloat)visibleKeyboardHeight{
#if !defined(SV_APP_EXTENSIONS)
    return 0;
    UIWindow *keyboardWindow = nil;
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]){
        if(![[testWindow class] isEqual:[UIWindow class]]){
            keyboardWindow = testWindow;
            break;
        }
    }
    
    for (__strong UIView *possibleKeyboard in [keyboardWindow subviews]){
        if([possibleKeyboard isKindOfClass:NSClassFromString(@"UIPeripheralHostView")] || [possibleKeyboard isKindOfClass:NSClassFromString(@"UIKeyboard")]){
            return CGRectGetHeight(possibleKeyboard.bounds);
        } else if([possibleKeyboard isKindOfClass:NSClassFromString(@"UIInputSetContainerView")]){
            for (__strong UIView *possibleKeyboardSubview in [possibleKeyboard subviews]){
                if([possibleKeyboardSubview isKindOfClass:NSClassFromString(@"UIInputSetHostView")]){
                    return CGRectGetHeight(possibleKeyboardSubview.bounds);
                }
            }
        }
    }
#endif
    return 0;
}

+ (void)changeOrientation:(UIInterfaceOrientation)orientation
{
  CGFloat angle = 0;
  switch (orientation) {
    case UIInterfaceOrientationLandscapeLeft:
      angle = - M_PI_2;
      break;
    case UIInterfaceOrientationLandscapeRight:
      angle = M_PI_2;
      break;
    default:
      break;
  }
  [YDOverWriteSVProgressHUD sharedView].transform = CGAffineTransformMakeRotation(angle);
}

@end


