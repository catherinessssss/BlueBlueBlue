//
//  Peripheral.m
//  blueblueblue
//
//  Created by obzone on 16/4/8.
//  Copyright © 2016年 obzone. All rights reserved.
//

#import "Peripheral.h"
#import <objc/runtime.h>

@implementation CBPeripheral (RSS)

- (void)setRss:(NSInteger)rss {

    objc_setAssociatedObject(self, @"rss", @(rss), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)rss {

    return [objc_getAssociatedObject(self, @"rss") integerValue];
}

@end
