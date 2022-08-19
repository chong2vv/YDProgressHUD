//
//  YDViewController.m
//  YDProgressHUD
//
//  Created by wangyuandong on 08/18/2022.
//  Copyright (c) 2022 wangyuandong. All rights reserved.
//

#import "YDViewController.h"
#import <YDProgressHUD/YDProgressHUD.h>
#import <YDProgressHUD/UIViewController+Toast.h>
#import "YDProgressHUDConfig+YDUIConfig.h"

@interface YDViewController ()

@end

@implementation YDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIButton *testBt = [UIButton buttonWithType:UIButtonTypeSystem];
    [testBt setTitle:@"测试" forState:UIControlStateNormal];
    [self.view addSubview:testBt];
    testBt.frame = CGRectMake(100, 200, 200, 200);
    [testBt addTarget:self action:@selector(testAction) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)testAction {
    [self showErrorText:@"cuowu"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
