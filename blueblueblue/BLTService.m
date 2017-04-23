//
//  BLTService.m
//  zoneBLT
//
//  Created by obzone on 16/4/8.
//  Copyright © 2016年 obzone. All rights reserved.
//

#import "BLTService.h"
#import "Peripheral.h"

NSString *const didConnectedperipheralNotificationKey = @"didConnectedperipheralNotificationKey";
NSString *const didDisconnectedperipheralNotificationKey = @"didDisconnectedperipheralNotificationKey";
NSString *const didBLTStatusEnable = @"didBLTStatusEnable";
NSString *const didBLTStatusUnusable = @"didBLTStatusUnusable";

@interface BLTService () <CBCentralManagerDelegate ,CBPeripheralDelegate>

@property (nonatomic ,strong)CBCharacteristic *characteristicWrite; // 可写的属性

@property (nonatomic ,strong)NSTimer          *traceTimer;          // 追踪设备时，用到的定时器

@property (nonatomic ,copy) void(^discoverPeripheralCallBack)(CBPeripheral * ,NSNumber *);  // 搜索到周边设备后回调block
@property (nonatomic ,copy) void(^didTraceRSSICallback)(NSNumber * ,CBPeripheral *);        // 获取到设备rssi值后的回调
@property (nonatomic ,copy) void(^requestSuccessCallback)(NSData *responseData);                        // 请求成功回调
@property (nonatomic ,copy) void(^requestFailedCallback)(NSError *error);                   // 请求失败回调

@property (nonatomic ,strong) NSError *error; // 连接错误❌

@end

@implementation BLTService

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _centerManager = [[CBCentralManager alloc] initWithDelegate:self
                                                              queue:nil
                                                            options:@{CBCentralManagerOptionShowPowerAlertKey:@YES, CBCentralManagerOptionRestoreIdentifierKey:@"restoreIdentifierKey"}];
        
    }
    return self;
}

+ (instancetype)prepare{

    static BLTService * bltService;
    
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
       
        bltService = [self new];
        bltService.peripheralsSet = [NSMutableSet set];
        
    });
    
    return bltService;

}

- (void)scanPeripheralWithReturnPeripheralsCallback:(void(^)(CBPeripheral *peripheral ,NSNumber *number))callback{

    self.discoverPeripheralCallBack = callback;
    [_peripheralsSet removeAllObjects];

    [_centerManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}]; // 搜索未与手机配对的设备（未配对设备会广播）aigo手环不能指定服务搜索，根据设备name过滤
    
}
- (void)stopScanPeripheral{

    [_centerManager stopScan];

}
- (void)connectPeripheral:(CBPeripheral *)peripheral withDidconnectedCallback:(void(^)(BOOL isConnected))callback{
    
    self.didConnectPeripheralCallback = callback;
    
    [_centerManager connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES}];
    
}
- (void)disconnectPerpheralWithDidDisconnectedCallback:(void(^)())callback{
    self.bltCenterDisconnectPeripheralCallback = callback;

    [_centerManager cancelPeripheralConnection:_peripheral];
    
}
- (void)startTraceDeviceRSSIWithTraceCallback:(void(^)(NSNumber *number ,CBPeripheral *peripheral))callback{
    
    [_traceTimer invalidate];

    self.didTraceRSSICallback = callback;
    
    _traceTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(traceDevice) userInfo:nil repeats:YES];
    
}
- (void)stopTraceDeviceRSSI{

    [_traceTimer invalidate];
    _traceTimer = nil;
    
}
- (void)sendRequestWithData:(NSData *)data SuccessCallback:(void(^)(NSData *data))successBlock andErrorCallback:(void(^)(NSError *))errorBlock{

    self.requestSuccessCallback = successBlock;
    self.requestFailedCallback = errorBlock;
    
    if (_characteristicWrite == nil) {
        
        if (_requestFailedCallback) _requestFailedCallback(nil);
    }
    
    [_peripheral writeValue:data forCharacteristic:_characteristicWrite type:CBCharacteristicWriteWithResponse];
   
}

- (void)traceDevice{

    [_peripheral readRSSI];
    
}

#pragma mark - ### CBCentralManager - delegate ####
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{ // 搜索周边设备
    
    NSLog(@"centralManager state%ld",(long)central.state);
    
    switch (central.state) {
        case CBCentralManagerStatePoweredOn: //Bluetooth is currently powered on and available to use
        
//            [self reconnectLastConnectedPerpheral];
//            [central scanForPeripheralsWithServices:nil options:nil];
            
            break;
            
        case CBCentralManagerStatePoweredOff: // Bluetooth is currently powered off.
            
            [[NSNotificationCenter defaultCenter] postNotificationName:didBLTStatusUnusable object:nil];
            
            _peripheral = nil;
            
            break;
            
        default:
            break;
    }
    
}
/**
 NSString *const CBCentralManagerRestoredStatePeripheralsKey;
 NSString *const CBCentralManagerRestoredStateScanServicesKey;
 NSString *const CBCentralManagerRestoredStateScanOptionsKey;
 */
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict{ // 系统唤起程序后执行方法

   self.centerManager = central;
    _centerManager.delegate = self;
    [self reconnectLastConnectedPerpheral];
    

}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
    peripheral.rss = [RSSI integerValue];
    
    [_peripheralsSet addObject:peripheral];
    if (_discoverPeripheralCallBack) {
            
        _discoverPeripheralCallBack(peripheral,RSSI);
            
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{

    peripheral.delegate = self;

    // storage uuid 4 reconnect
    
    
    [peripheral discoverServices:nil];

}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{

    if (error) { // 如果是意外断开则重连 （error ！＝ nil）
        
        _error = error;
        [self reconnectLastConnectedPerpheral];
        
    } else {
        
//        [User currentUser].uuid = nil;
//        _peripheral = nil;
    
        if (_bltCenterDisconnectPeripheralCallback) { // 手动断开（error ＝＝ nil）
            
            _bltCenterDisconnectPeripheralCallback(peripheral ,nil);
            
        }
    
    }

}

- (void)reconnectLastConnectedPerpheral{ // 重连最后一次连接过的设备

    NSUUID *lastConnectedUUID = nil;
    //[[NSUUID alloc] initWithUUIDString:[User currentUser].uuid];
    [_peripheralsSet removeAllObjects];
    [_peripheralsSet addObjectsFromArray:[_centerManager retrievePeripheralsWithIdentifiers:@[]]]; // 根据最后一次持久话的id获取可用周边设备
    
    if (_peripheralsSet.count == 1) { // 取到唯一设备

        [_peripheralsSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            
            [_centerManager connectPeripheral:obj options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES}];
            
        }];
        
    } else { // 遵循官方连接流程第二步
    
        
        [_peripheralsSet addObjectsFromArray:[_centerManager retrieveConnectedPeripheralsWithServices:@[]]] ; // 获取手机已经连接的周边设备
        
        NSString *XXX = @"";
        
        if (_peripheralsSet.count > 0  && XXX) {
            
            
            for (CBPeripheral * peripheral in _peripheralsSet) {
                
                if (!XXX) { //
                    if ([peripheral.identifier.UUIDString isEqualToString:XXX]){
                        [_centerManager connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES}];
                    }
                }
            }
        }else{
        
            if(_peripheral) [_centerManager connectPeripheral:_peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES}]; // 用于持久化的种子请求
            
            if (_bltCenterDisconnectPeripheralCallback) {
                
                _bltCenterDisconnectPeripheralCallback(nil ,_error);
                
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:didDisconnectedperipheralNotificationKey object:nil];
        
        }
        
    }

}

#pragma mark - ## peripheral - delegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    for (CBService * service in peripheral.services) {
        NSLog(@"%@", service.UUID.UUIDString);
        NSLog(@"%@", SERVICE_UUID.UUIDString);
        if ([service.UUID.UUIDString isEqualToString:SERVICE_UUID.UUIDString]) {
            
            [peripheral discoverCharacteristics:nil forService:service];
            
        }
        
    }

}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error{

    for (CBCharacteristic * characteristic in service.characteristics) {
        
        NSLog(@"%@", characteristic.UUID.UUIDString);
        if ([characteristic.UUID.UUIDString isEqualToString:writecharateUUID.UUIDString]) { // 保存可写属性，供后面发送请求
            
            self.characteristicWrite = characteristic;
            
        }
        if ([characteristic.UUID.UUIDString isEqualToString:notifycharateUUID.UUIDString]) { // 订阅属性，供后面获取返回数据
            
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            [_centerManager stopScan];
            
            self.peripheral = peripheral;
            if (_didConnectPeripheralCallback) {
                
                _didConnectPeripheralCallback(YES);
                
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:didConnectedperipheralNotificationKey object:nil];
        }
        
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:didBLTStatusEnable object:nil];
}
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error {

    if (error)return;
    
    if (_didTraceRSSICallback) {
        
        _didTraceRSSICallback(RSSI ,peripheral);
        
    }

}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{

//    NSLog(@"didUpdateValueForCharacteristic = %@",characteristic.value);
    
    if (error) {
    
        if (_requestFailedCallback) _requestFailedCallback(error);
    
    }
    else{
        
        if (_dataFilterCallback) _dataFilterCallback(characteristic.value);
        if (_requestSuccessCallback) _requestSuccessCallback(characteristic.value);
    
    }
    

}

@end
