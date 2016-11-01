//
//  BTService.h
//  Arduino_Servo
//
//  Created by Owen Lacy Brown on 5/21/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

/* Services & Characteristics UUIDs */
#define RWT_BLE_SERVICE_UUID		[CBUUID UUIDWithString:@"B8E06067-62AD-41BA-9231-206AE80AB550"]
#define RWT_POSITION_CHAR_UUID		[CBUUID UUIDWithString:@"BF45E40A-DE2A-4BC8-BBA0-E5D6065F1B4B"]

/* Notifications */
static NSString* const RWT_BLE_SERVICE_CHANGED_STATUS_NOTIFICATION = @"kBLEServiceChangedStatusNotification";


/* BTService */
@interface BTService : NSObject <CBPeripheralDelegate>

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral;
- (void)reset;
- (void)startDiscoveringServices;

- (void)writePosition:(UInt8)position;

@end
