//
//  HomePage.m
//  blueblueblue
//
//  Created by xiaoyin.li on 2017/4/23.
//  Copyright © 2017年 xiaoyin.li. All rights reserved.
//

#import "HomePage.h"
#import "BLTService.h"
#import "Peripheral.h"
#import "ActivityDetection.h"

@interface HomePage ()

@end

@implementation HomePage {

    NSArray<CBPeripheral *> *_peripheralArray;
    BLTService *_bleService;
    
    UITableViewCell *_switchBle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = 60;
    
    
    _bleService = [BLTService prepare];
    
    _switchBle = [[NSBundle mainBundle] loadNibNamed:@"SwitchBle" owner:nil options:nil][0];
    [(UISwitch *)_switchBle.accessoryView addTarget:self action:@selector(switchClicked:) forControlEvents:UIControlEventValueChanged];
}

- (void)switchClicked:(UISwitch *)switchButton {

    if (switchButton.isOn) {
        NSLog(@"-----------start scan--------------");
        [_bleService scanPeripheralWithReturnPeripheralsCallback:^(CBPeripheral *peripheral, NSNumber *number) {
            _peripheralArray = [_bleService.peripheralsSet allObjects];
            [self.tableView reloadData];
        }];
    }
    else {
        NSLog(@"-----------stop scan--------------");
        [_bleService stopScanPeripheral];
        
        _peripheralArray = @[];
        [self.tableView reloadData];
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (section == 0) {
        return 1;
    }
    return _peripheralArray.count;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    if (section == 1) {
        return _peripheralArray.count > 0 ? @"Device Nearby" : @"";
    }
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        
        return _switchBle;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"reuseIdentifier"];
    }
    
    NSString *name = _peripheralArray[indexPath.row].name;
    
    cell.textLabel.text = name ? name : @"Unnamed" ;
    int rssLevel = 5 - ceilf((0-_peripheralArray[indexPath.row].rss - 40)/10);
    rssLevel = rssLevel > 5 ? 5 : rssLevel ;
    cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"signal%d", rssLevel]];
    
    return cell;
}

#pragma mark - table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 1) {
        [_bleService connectPeripheral:_peripheralArray[indexPath.row] withDidconnectedCallback:^(BOOL isConnected) {
            NSLog(@"Connected");
            [self.navigationController pushViewController:[ActivityDetection new] animated:YES];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [_bleService stopScanPeripheral];
            _peripheralArray = @[];
            [self.tableView reloadData];
            [(UISwitch *)_switchBle.accessoryView setOn:NO];
        }];
    }
}

@end
