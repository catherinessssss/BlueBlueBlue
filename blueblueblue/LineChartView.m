//
//  LineChartView.m
//  blueblueblue
//
//  Created by xiaoyin.li on 2017/4/23.
//  Copyright © 2017年 xiaoyin.li. All rights reserved.
//

#import "LineChartView.h"

@implementation LineChartView

- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextBeginPath(context);
    
    CGContextSaveGState(context);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, nil, 0, CGRectGetHeight(rect));
    int width = CGRectGetWidth(rect)/(_dataArray.count - 1);
    int height = CGRectGetHeight(rect)*3/4;
    for (int i = 0; i < _dataArray.count; i ++) {
        NSNumber *number = _dataArray[i];
        CGPathAddLineToPoint(path, nil, width*i, CGRectGetHeight(rect) - number.integerValue*height - 2);
    }
    CGContextAddPath(context, path);
    CGContextSetLineWidth(context, 2);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);

}

@end
