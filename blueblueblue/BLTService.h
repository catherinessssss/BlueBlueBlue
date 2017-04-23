//
//  BLTService.h
//  zoneBLT
//
//  Created by obzone on 16/4/8.
//  Copyright © 2016年 obzone. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define uuid(p) [CBUUID UUIDWithString:p]
#define SERVICE_UUID uuid(@"F000AA80-0451-4000-B000-000000000000")
#define writecharateUUID uuid(@"F000AA82-0451-4000-B000-000000000000")
#define notifycharateUUID uuid(@"F000AA81-0451-4000-B000-000000000000")

extern NSString *const didConnectedperipheralNotificationKey;
extern NSString *const didDisconnectedperipheralNotificationKey;
extern NSString *const didBLTStatusEnable;
extern NSString *const didBLTStatusUnusable;

@interface BLTService : NSObject

+ (instancetype)prepare;

@property (nonatomic ,assign) BOOL bleIsOn;

@property (nonatomic ,strong)CBCentralManager *centerManager;
@property (nonatomic ,strong)CBPeripheral     *peripheral; // 当前连接的蓝牙设备
@property (nonatomic ,strong)NSMutableSet     *peripheralsSet;// 当前搜索到的蓝牙设备

@property (nonatomic ,copy) void(^dataFilterCallback)(NSData *responseData); // 接受到蓝牙设备发送来的数据时的过滤器回调方法

@property (nonatomic ,copy) void(^didConnectPeripheralCallback)(BOOL isConnected);                                                  // 连接设备后回调block
@property (nonatomic ,copy) void(^bltCenterDisconnectPeripheralCallback)(CBPeripheral *peripheral ,NSError *error); // 蓝牙设备断开后回调方法

- (void)scanPeripheralWithReturnPeripheralsCallback:(void(^)(CBPeripheral *peripheral ,NSNumber *number))callback; // 搜索设备
- (void)stopScanPeripheral;                                                                                        // 停止搜索

- (void)connectPeripheral:(CBPeripheral *)peripheral withDidconnectedCallback:(void(^)(BOOL isConnected))callback ; // 🔗连接设备
- (void)disconnectPerpheralWithDidDisconnectedCallback:(void(^)())callback;                         // 断开当前🔗连接

- (void)startTraceDeviceRSSIWithTraceCallback:(void(^)(NSNumber *number ,CBPeripheral *peripheral))callback; // 开始跟踪设备
- (void)stopTraceDeviceRSSI;                                                                                 // 停止追踪设备

- (void)sendRequestWithData:(NSData *)data SuccessCallback:(void(^)(NSData *data))successBlock andErrorCallback:(void(^)(NSError *))errorBlock; // 发送请求

@end
