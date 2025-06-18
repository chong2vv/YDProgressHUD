//
//  YDViewController.m
//  YDProgressHUD
//
//  Created by wangyuandong on 08/18/2022.
//  Copyright (c) 2022 wangyuandong. All rights reserved.
//

#import "YDViewController.h"
#import "YDLoadingViewController.h"
#import <YDSVProgressHUD/YDProgressHUD.h>
#import <YDSVProgressHUD/UIViewController+Toast.h>
#import "YDProgressHUDConfig+YDUIConfig.h"

@interface YDViewController ()

@end

@implementation YDViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"首页";
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *testBt = [UIButton buttonWithType:UIButtonTypeSystem];
    [testBt setTitle:@"测试" forState:UIControlStateNormal];
    [self.view addSubview:testBt];
    testBt.frame = CGRectMake(100, 200, 200, 200);
    [testBt addTarget:self action:@selector(testAction) forControlEvents:UIControlEventTouchUpInside];
    [YDProgressHUD setOffsetFromCenter:UIOffsetMake(0, 100)];
    
    
    
}

- (void)testAction {
    YDLoadingViewController *vc = [[YDLoadingViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
