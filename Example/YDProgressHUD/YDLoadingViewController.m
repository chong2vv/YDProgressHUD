//
//  YDLoadingViewController.m
//  YDProgressHUD_Example
//
//  Created by chong2vv on 2025/6/18.
//  Copyright © 2025 wangyuandong. All rights reserved.
//

#import "YDLoadingViewController.h"
#import <YDSVProgressHUD/YDProgressHUD.h>
#import <YDSVProgressHUD/UIViewController+Toast.h>

@interface TopViewControllerHelper : NSObject

+ (UIViewController *)topViewController;
+ (UIViewController *)topViewControllerFromWindow:(UIWindow *)window;

@end


@implementation TopViewControllerHelper

+ (UIViewController *)topViewController {
    UIWindow *keyWindow = [self keyWindow];
    return [self topViewControllerFromWindow:keyWindow];
}

+ (UIViewController *)topViewControllerFromWindow:(UIWindow *)window {
    UIViewController *rootVC = window.rootViewController;
    return [self findTopViewController:rootVC];
}

+ (UIWindow *)keyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
    }
    
    // Fallback for earlier iOS versions
    return [UIApplication sharedApplication].keyWindow;
}

+ (UIViewController *)findTopViewController:(UIViewController *)baseViewController {
    if ([baseViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)baseViewController;
        return [self findTopViewController:nav.visibleViewController];
    }
    
    if ([baseViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)baseViewController;
        return [self findTopViewController:tab.selectedViewController];
    }
    
    if (baseViewController.presentedViewController) {
        return [self findTopViewController:baseViewController.presentedViewController];
    }
    
    return baseViewController;
}

@end


@interface YDLoadingViewController ()

@end

@implementation YDLoadingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"测试页";
    self.view.backgroundColor = [UIColor whiteColor];
    [YDProgressHUD setContainerView: [TopViewControllerHelper topViewController].view];
    UIViewController *topVC = [TopViewControllerHelper topViewController];
    
}


@end
