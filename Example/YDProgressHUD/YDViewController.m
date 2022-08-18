//
//  YDViewController.m
//  YDProgressHUD
//
//  Created by wangyuandong on 08/18/2022.
//  Copyright (c) 2022 wangyuandong. All rights reserved.
//

#import "YDViewController.h"
#import <YDProgressHUD/YDProgressHUD.h>

@interface YDViewController ()

@end

@implementation YDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [YDProgressHUD showSuccessWithStatus:@"哈哈哈"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
