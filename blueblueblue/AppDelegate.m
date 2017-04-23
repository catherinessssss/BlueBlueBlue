//
//  AppDelegate.m
//  blueblueblue
//
//  Created by xiaoyin.li on 2017/4/22.
//  Copyright © 2017年 xiaoyin.li. All rights reserved.
//

#import "AppDelegate.h"
#import "BLTService.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [BLTService prepare];
    
    return YES;
}

@end
