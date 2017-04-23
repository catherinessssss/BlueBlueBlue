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
@property (weak, nonatomic) IBOutlet UILabel *ActivityStatus;


@property (weak, nonatomic) IBOutlet LineChartView *lineChartView;

@end

@implementation ActivityDetection {

    BLTService *_bltService;
    
    CMMotionManager *_motionManager;
    
    NSMutableArray *_dataArray;
    NSMutableArray *_acceArray;
    NSMutableArray *_accePhoneArray;
    NSMutableArray *_gyroArray;
    NSMutableArray *_gyroPhoneArray;
    float lastPhoneAccZ;
    float accThreshold;
    float accThresholdV;
    
    
    NSMutableArray *_chartData;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _bltService = [BLTService prepare];
    _dataArray = [NSMutableArray array];
    _acceArray = [NSMutableArray array];
    _gyroArray = [NSMutableArray array];
    _accePhoneArray = [NSMutableArray array];
    _gyroPhoneArray = [NSMutableArray array];
    accThreshold = 0.1;
    accThresholdV = 4;
    lastPhoneAccZ = 0;
    
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
    
    // AccelerometerValue
    float AccelerometerValueX = [self sensorMpu9250AccConvert:bytes[7] << 8 | bytes[6]];
    float AccelerometerValueY = [self sensorMpu9250AccConvert:bytes[9] << 8 | bytes[8]];
    float AccelerometerValueZ = [self sensorMpu9250AccConvert:bytes[11] << 8 | bytes[10]];
    
    _accelerometer.text = [NSString stringWithFormat:@"X :%.02f, Y :%.02f, Z :%.02f", AccelerometerValueX, AccelerometerValueY, AccelerometerValueZ];
    
    // GyrometerValue
    float GyrometerValueX = [self sensorMpu9250GyroConvert:bytes[1] << 8 | bytes[0]];
    float GyrometerValueY = [self sensorMpu9250GyroConvert:bytes[3] << 8 | bytes[2]];
    float GyrometerValueZ = [self sensorMpu9250GyroConvert:bytes[5] << 8 | bytes[4]];
    
    _gyro.text = [NSString stringWithFormat:@"X :%.02f, Y :%.02f, Z :%.02f", GyrometerValueX, GyrometerValueY, GyrometerValueZ];
    
    
    
    // AccelerometerSqrtResult
    float sqrtResult = [self sqrtWithValueX:AccelerometerValueX AndValueY:AccelerometerValueY AndValueZ:AccelerometerValueZ];
    
    
    // AccelerometerVerticalResult
    float AccV = [self calculateAngelWithValuex:AccelerometerValueX AndValueY:AccelerometerValueY AndValueZ:AccelerometerValueZ AndGyroValueX:GyrometerValueX AndGyroValueY:GyrometerValueY AndGyroValueZ:GyrometerValueZ];
    
    // drawChartData
    [_chartData addObject:@([self pushAccArrayWithSqrtResult:sqrtResult AndAccV: AccV])];
    
    _lineChartView.dataArray = _chartData;
    [_lineChartView setNeedsDisplay];
    
    // GyroSqarResult
    float gyroSqrtResult = [self sqrtWithValueX:GyrometerValueX AndValueY:GyrometerValueY AndValueZ:GyrometerValueZ];

    [self pushGyroArrayWithSqrtResult:gyroSqrtResult AcceAX: AccelerometerValueZ];
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

// sqrtResult function
- (float) sqrtWithValueX:(float)valueX AndValueY:(float)valueY AndValueZ:(float)valueZ {
    return sqrt(valueX*valueX + valueY*valueY + valueZ*valueZ);
}

// Calculate Av function
- (float) calculateAngelWithValuex:(float)valueX AndValueY:(float)valueY AndValueZ:(float)valueZ AndGyroValueX: (float) gyroX AndGyroValueY: (float) gyroY AndGyroValueZ: (float) gyroZ {
    
    float Av = fabsf(valueX * sinf(gyroZ) + valueY * sinf(gyroY) - valueZ * cosf(gyroY) * cosf(gyroZ));
//    NSLog(@"deg = %f" , Av);
    return Av;
}

// push Accelerometer to Array
- (BOOL) pushAccArrayWithSqrtResult:(float) sqrtResult AndAccV: (float) accV {
    BOOL fallFlag = false;
    
    if(_acceArray.count < 5) {
        
        [_acceArray addObject:@(sqrtResult)];
    } else {
        fallFlag = [self fallDetection: _acceArray AccV: accV];
        [_acceArray removeObjectAtIndex:0];
        [_acceArray addObject:@(sqrtResult)];
    }
    
    return fallFlag;
}

// Fall Dtection
- (BOOL) fallDetection: (NSMutableArray*) array AccV:(float) accV {
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
    
    if(difference > accThreshold && accV < accThresholdV) {
        NSLog(@"Falling Down Detected");
        return true;
    }
    return false;
}


- (BOOL) pushGyroArrayWithSqrtResult:(float) sqrtResult AcceAX :(float) acceAX {
    
    if(_gyroArray.count < 5) {
        
        [_gyroArray addObject:@(sqrtResult)];
    } else {
        [self gestureDetection:_acceArray AccePhoneArray:_accePhoneArray GyroArray:_gyroArray GyroPhoneArray:_gyroPhoneArray AcceAX:acceAX];
        [_gyroArray removeObjectAtIndex:0];
        [_gyroArray addObject:@(sqrtResult)];
    }
    
    return true;
}

// Get Angel
-(float) getAngel: (float) Acc {
    float angel = acosf(fabsf(Acc) / 9.8);
    NSLog(@"Acc is %f, angel is %f", Acc , angel);
    return  angel;
}


-(BOOL) gestureDetection: (NSMutableArray*) acceArray AccePhoneArray:(NSMutableArray*) accePhoneArray GyroArray: (NSMutableArray*) gyroArray GyroPhoneArray: (NSMutableArray*) gyroPhoneArray AcceAX: (float) acceAX {
    if(acceArray.count == 5 && accePhoneArray.count == 5 && gyroArray.count == 5 && gyroPhoneArray.count == 5) {
    
        float aA = [self calculateDifference: acceArray];
        float bA = [self calculateDifference: accePhoneArray];
        float wA = [self calculateDifference: gyroArray];
        float wB = [self calculateDifference: gyroPhoneArray];
        
        float angel1 = [self getAngel:(acceAX)];
        float angel2 = [self getAngel:lastPhoneAccZ];

        if(aA < 0.4 && bA < 0.4 && wA < 60 && wB < 60) {
            if(angel1 < 1.5 && angel2 < 1.5) {
                NSLog(@"Lying Down");
                _ActivityStatus.text = @"Lying Down";
            } else if (angel1 < 1.5 && angel2 > 1.5) {
                NSLog(@"Bending");
                _ActivityStatus.text = @"Bending";
            } else if (angel1 > 1.5 && angel2 < 1.5 ) {
                NSLog(@"Sitting");
                _ActivityStatus.text = @"Sitting";
            } else if(angel1 > 1.5 && angel2 > 1.5 ) {
                NSLog(@"Standing");
                _ActivityStatus.text = @"Standing";
            }
        }
//        NSLog(@"aA: %f, aB: %f, aC: %f, AD: %f", aA,bA,wA,wB);
    }
    
    return true;
}

-(float) calculateDifference: (NSMutableArray*) array {
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

    return difference;
}

- (void)useAccelerometerPush{
    //初始化全局管理对象
    _motionManager = [[CMMotionManager alloc] init];

    //告诉manager，更新频率是1000Hz
    _motionManager.accelerometerUpdateInterval = 1;
    _motionManager.gyroUpdateInterval = 1;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //Push方式获取和处理数据
    [_motionManager startAccelerometerUpdatesToQueue:queue
                                         withHandler:^(CMAccelerometerData *accelerometerData, NSError *error)
     {
         if(_accePhoneArray.count < 5) {
             
             [_accePhoneArray addObject: @([self sqrtWithValueX:accelerometerData.acceleration.x AndValueY:accelerometerData.acceleration.y AndValueZ:accelerometerData.acceleration.z])];
         } else {
             
             [_accePhoneArray removeObjectAtIndex:0];
             [_accePhoneArray addObject: @([self sqrtWithValueX:accelerometerData.acceleration.x AndValueY:accelerometerData.acceleration.y AndValueZ:accelerometerData.acceleration.z])];
         }
         lastPhoneAccZ = accelerometerData.acceleration.z;

//         NSLog(@"accelerometerData%p", accelerometerData);
//         NSLog(@"X = %.04f",accelerometerData.acceleration.x);
//         NSLog(@"Y = %.04f",accelerometerData.acceleration.y);
//         NSLog(@"Z = %.04f",accelerometerData.acceleration.z);
     }];
    
    //Push方式获取和处理数据
    [_motionManager startGyroUpdatesToQueue:queue
                                withHandler:^(CMGyroData *gyroData, NSError *error)
     {
         if(_gyroPhoneArray.count < 5) {
             
             [_gyroPhoneArray addObject: @([self sqrtWithValueX:(gyroData.rotationRate.x * 180 / M_PI) AndValueY: (gyroData.rotationRate.y * 180 / M_PI) AndValueZ: (gyroData.rotationRate.z * 180 / M_PI)])];
         } else {
             
             [_gyroPhoneArray removeObjectAtIndex:0];
             [_gyroPhoneArray addObject: @([self sqrtWithValueX:(gyroData.rotationRate.x * 180 / M_PI) AndValueY: (gyroData.rotationRate.y * 180 / M_PI) AndValueZ: (gyroData.rotationRate.z * 180 / M_PI)])];
         }

//         NSLog(@"Gyro Rotation x = %.04f", gyroData.rotationRate.x);
//         NSLog(@"Gyro Rotation y = %.04f", gyroData.rotationRate.y);
//         NSLog(@"Gyro Rotation z = %.04f", gyroData.rotationRate.z);
     }];

}

@end
