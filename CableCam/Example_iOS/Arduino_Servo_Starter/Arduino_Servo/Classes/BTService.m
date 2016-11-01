//
//  BTService.m
//  Arduino_Servo
//
//  Created by Owen Lacy Brown on 5/21/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import "BTService.h"


@interface BTService()
@property (strong, nonatomic) CBPeripheral *peripheral;
@property (strong, nonatomic) CBCharacteristic *positionCharacteristic;
@end

@implementation BTService

#pragma mark - Lifecycle

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral {
  self = [super init];
  if (self) {
    self.peripheral = peripheral;
    [self.peripheral setDelegate:self];
  }
  return self;
}

- (void)dealloc {
  [self reset];
}

- (void)startDiscoveringServices {
  [self.peripheral discoverServices:@[RWT_BLE_SERVICE_UUID]];
}

- (void)reset {
  
  if (self.peripheral) {
    self.peripheral = nil;
  }
  
  // Deallocating therefore send notification
  [self sendBTServiceNotificationWithIsBluetoothConnected:NO];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  NSArray *services = nil;
  NSArray *uuidsForBTService = @[RWT_POSITION_CHAR_UUID];
  
  if (peripheral != self.peripheral) {
    //NSLog(@"Wrong Peripheral.\n");
    return ;
  }
  
  if (error != nil) {
    //NSLog(@"Error %@\n", error);
    return ;
  }
  
  services = [peripheral services];
  if (!services || ![services count]) {
    //NSLog(@"No Services");
    return ;
  }
  
  for (CBService *service in services) {
    if ([[service UUID] isEqual:RWT_BLE_SERVICE_UUID]) {
      [peripheral discoverCharacteristics:uuidsForBTService forService:service];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
  NSArray     *characteristics    = [service characteristics];
  
  if (peripheral != self.peripheral) {
    //NSLog(@"Wrong Peripheral.\n");
    return ;
  }
  
  if (error != nil) {
    //NSLog(@"Error %@\n", error);
    return ;
  }
  
  for (CBCharacteristic *characteristic in characteristics) {
    if ([[characteristic UUID] isEqual:RWT_POSITION_CHAR_UUID]) {
      self.positionCharacteristic = characteristic;
      
      // Send notification that Bluetooth is connected and all required characteristics are discovered
      [self sendBTServiceNotificationWithIsBluetoothConnected:YES];
    }
  }
}

#pragma mark - Private

- (void)writePosition:(UInt8)position {
  // TODO: Add implementation
}

- (void)sendBTServiceNotificationWithIsBluetoothConnected:(BOOL)isBluetoothConnected {
  NSDictionary *connectionDetails = @{@"isConnected": @(isBluetoothConnected)};
  [[NSNotificationCenter defaultCenter] postNotificationName:RWT_BLE_SERVICE_CHANGED_STATUS_NOTIFICATION object:self userInfo:connectionDetails];
}

@end
