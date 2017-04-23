//
//  ActivityDetection.m
//  blueblueblue
//
//  Created by xiaoyin.li on 2017/4/23.
//  Copyright © 2017年 xiaoyin.li. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import "ActivityDetection.h"
#import "LineChartView.h"
#import "BLTService.h"

@interface ActivityDetection ()

@property (weak, nonatomic) IBOutlet UILabel *gyro;
@property (weak, nonatomic) IBOutlet UILabel *accelerometer;

@property (weak, nonatomic) IBOutlet LineChartView *lineChartView;

@end

@implementation ActivityDetection {

    BLTService *_bltService;
    
    CMMotionManager *_motionManager;
    
    NSMutableArray *_dataArray;
    NSMutableArray *_acceArray;
    NSMutableArray *_gyroArray;
    float accThreshold;
    
    
    NSMutableArray *_chartData;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _bltService = [BLTService prepare];
    _dataArray = [NSMutableArray array];
    _acceArray = [NSMutableArray array];
    _gyroArray = [NSMutableArray array];
    accThreshold = 0.1;
    
    _chartData = [NSMutableArray array];
    
    UInt8 byte[2] = {0x3F, 0x02};
    [_bltService sendRequestWithData:[NSData dataWithBytes:byte length:sizeof(byte)]
                     SuccessCallback:^(NSData *data) {
                         [self decodeData:data];
                     }
                    andErrorCallback:^(NSError *error) {
                        
                    }];
    
    [self useAccelerometerPush];

}

- (void)viewDidDisappear:(BOOL)animated {

    [_bltService disconnectPerpheralWithDidDisconnectedCallback:^{
        
    }];
}

- (void)decodeData:(NSData *)data {

    UInt8 bytes[18] = {0};
    [data getBytes:bytes length:18];
    
    float AccelerometerValueX = [self sensorMpu9250AccConvert:bytes[7] << 8 | bytes[6]];
    float AccelerometerValueY = [self sensorMpu9250AccConvert:bytes[9] << 8 | bytes[8]];
    float AccelerometerValueZ = [self sensorMpu9250AccConvert:bytes[11] << 8 | bytes[10]];
    _accelerometer.text = [NSString stringWithFormat:@"X :%.02f, Y :%.02f, Z :%.02f", AccelerometerValueX, AccelerometerValueY, AccelerometerValueZ];
    
    float sqrtResult = [self sqrtWithValueX:AccelerometerValueX AndValueY:AccelerometerValueY AndValueZ:AccelerometerValueZ];
    
    [_chartData addObject:@([self pushAccArray:sqrtResult])];
    
    _lineChartView.dataArray = _chartData;
    [_lineChartView setNeedsDisplay];
    
    float GyrometerValueX = [self sensorMpu9250GyroConvert:bytes[1] << 8 | bytes[0]];
    float GyrometerValueY = [self sensorMpu9250GyroConvert:bytes[3] << 8 | bytes[2]];
    float GyrometerValueZ = [self sensorMpu9250GyroConvert:bytes[5] << 8 | bytes[4]];
    _gyro.text = [NSString stringWithFormat:@"X :%.02f, Y :%.02f, Z :%.02f", GyrometerValueX, GyrometerValueY, GyrometerValueZ];
}

- (float) sensorMpu9250GyroConvert:(int16_t) data {
    return (data * 1.0) / (65536 / 500);
}

- (float) sensorMpu9250AccConvert:(int16_t) data {
    if(data > 32767) {
        data = data - 65536;
    }
    
    return (data * 1.0) / (32768 / 8);

}

- (float) sqrtWithValueX:(float)valueX AndValueY:(float)valueY AndValueZ:(float)valueZ {
    return sqrt(valueX*valueX + valueY*valueY + valueZ*valueZ);
}

- (float) calculateAngelWithValuex:(float)valueX AndValueY:(float)valueY AndValueZ:(float)valueZ AndSqrtValue: (float)sqrtValue {
    float Av = fabsf(valueX * sinf(acosf(valueZ)) + valueY * sinf(acosf(valueY)) - valueZ * cosf(acosf(valueY)) * cosf(acosf(valueZ)));
    
    return Av;
}

- (BOOL) pushAccArray:(float) sqrtResult {
    BOOL fallFlag = false;
    
    if(_acceArray.count < 5) {
        
        [_acceArray addObject:@(sqrtResult)];
    } else {
        fallFlag = [self fallDetection: _acceArray];
        [_acceArray removeObjectAtIndex:0];
    }
    
    return fallFlag;
}

- (BOOL) fallDetection: (NSMutableArray*) array {
    float value0 = (fabsf([[array objectAtIndex:0] floatValue] - [[array objectAtIndex:1] floatValue])) * 1.0;
    float value1 = (fabsf([[array objectAtIndex:1] floatValue] - [[array objectAtIndex:2] floatValue])) * 1.0;
    float value2 = (fabsf([[array objectAtIndex:2] floatValue] - [[array objectAtIndex:3] floatValue])) * 1.0;
    float value3 = (fabsf([[array objectAtIndex:3] floatValue] - [[array objectAtIndex:4] floatValue])) * 1.0;
    
    float maxValue = 0.0;
    float minValue = 0.0;
    NSArray *valueArray = @[@(value0), @(value1), @(value2), @(value3)];

    for(int i = 0; i < 3; i++) {
        maxValue = MAX([valueArray[i] floatValue], [valueArray[i+1] floatValue]);
        minValue = MIN([valueArray[i] floatValue], [valueArray[i+1] floatValue]);
    }
    
    float difference = fabsf(maxValue - minValue);
//    NSLog(@"difference %f" , difference);
    
    if(difference > accThreshold) {
        NSLog(@"Falling Down Detected");
        return true;
    }
    return false;
}

//TODO
- (BOOL) pushGyroArray:(float) sqrtResult {
    
    if(_gyroArray.count < 5) {
        
        [_gyroArray addObject:@(sqrtResult)];
    } else {
        
        [_gyroArray removeObjectAtIndex:0];
    }
    
    return true;
}

//TODO
-(BOOL) gestureDetection: (NSMutableArray*) array {
    return true;
}

- (void)useAccelerometerPush{
    //初始化全局管理对象
    _motionManager = [[CMMotionManager alloc] init];
    //判断加速度计可不可用，判断加速度计是否开启
    //告诉manager，更新频率是100Hz
    _motionManager.accelerometerUpdateInterval = 0.1;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //Push方式获取和处理数据
    [_motionManager startAccelerometerUpdatesToQueue:queue
                                         withHandler:^(CMAccelerometerData *accelerometerData, NSError *error)
     {
//         NSLog(@"X = %.04f",accelerometerData.acceleration.x);
//         NSLog(@"Y = %.04f",accelerometerData.acceleration.y);
//         NSLog(@"Z = %.04f",accelerometerData.acceleration.z);
     }];
    
    //Push方式获取和处理数据
    [_motionManager startGyroUpdatesToQueue:queue
                                withHandler:^(CMGyroData *gyroData, NSError *error)
     {
//         NSLog(@"Gyro Rotation x = %.04f", gyroData.rotationRate.x);
//         NSLog(@"Gyro Rotation y = %.04f", gyroData.rotationRate.y);
//         NSLog(@"Gyro Rotation z = %.04f", gyroData.rotationRate.z);
     }];

}

@end
