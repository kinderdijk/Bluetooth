//
//  BluetoothServices.swift
//  CableCam
//
//  Created by Jon Pendlebury on 4/26/15.
//  Copyright (c) 2015 CaptureBeyondLimits. All rights reserved.
//

import Foundation
import CoreBluetooth

let BLEServiceUUID = CBUUID(string: "1e3033af-3edd-425b-98ff-5edc884ad57e")
let SpeedCharUUID = CBUUID(string: "71744276-c58b-46cc-933d-33ba136bdbfc")
let DeviceNameUUID = CBUUID(string: "64890478-5dd0-480b-98b1-ef21c66f87f7")
let GimbalOtherUUID = CBUUID(string: "61eb902b-4e0c-42ac-aa60-443f0c1ecd7a")
let GimbalRollUUID = CBUUID(string: "f20bd80b-730b-4b81-837b-cea6c26c6ef0")
let BatteryUUID = CBUUID(string: "0f9437de-dff4-4035-a596-339d4dbe3f8b");
let BLEdeviceUUID = CBUUID(string: "1800")
let BLEtestUUID = CBUUID(string: "aa653a5a-3fba-2a69-482d-f806ec9f0f37")
let BLEServiceChangedStatusNotification = "kBLEServiceChangedStatusNotification"

class BluetoothServices: NSObject, CBPeripheralDelegate {
    var peripheral: CBPeripheral?
    var speedCharacteristic: CBCharacteristic?
    var gimbalOtherCharacteristic: CBCharacteristic?
    var gimbalRollCharacteristic: CBCharacteristic?
    var deviceNameCharacteristic: CBCharacteristic?
    var batteryLevelCharacteristic: CBCharacteristic?
    
    var batteryReadValue: UInt32 = 0
    var batteryCount: Float = 0
    var batteryLevel: Float = 0
    
    var batteryArray = [UInt32](count: 256, repeatedValue: 0)
    var index: Int = 0
    
    init(initWithPeripheral peripheral:CBPeripheral) {
        super.init()
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
    }
    
    deinit {
        self.reset()
    }
    
    func reset() {
        if peripheral != nil {
            peripheral = nil
        }
        
        // Deallocating therefore send notification
        self.sendBTServiceNotificationWithIsBluetoothConnected(false)
    }
    
    func startDiscoveringServices() {
        self.peripheral?.discoverServices([BLEServiceUUID])
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        println("Discovered services.")
        let uuidsForBTService: [CBUUID] = [SpeedCharUUID, GimbalOtherUUID, GimbalRollUUID, DeviceNameUUID, BatteryUUID]
        
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        if ((peripheral.services == nil) || (peripheral.services.count == 0)) {
            // No Services
            return
        }
        
        for service in peripheral.services {
            if service.UUID == BLEServiceUUID {
                peripheral.discoverCharacteristics(uuidsForBTService, forService: service as! CBService)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        println("Service characteristic: \(service.characteristics.count)")
        
        for characteristic in service.characteristics {
            if characteristic.UUID == SpeedCharUUID
            {
                self.speedCharacteristic = (characteristic as! CBCharacteristic)
//                peripheral.setNotifyValue(true, forCharacteristic: characteristic as CBCharacteristic)
                
                // Send notification that Bluetooth is connected and all required characteristics are discovered
                self.sendBTServiceNotificationWithIsBluetoothConnected(true)
            }
            else if characteristic.UUID == GimbalOtherUUID
            {
                self.gimbalOtherCharacteristic = (characteristic as! CBCharacteristic)
            }
            else if characteristic.UUID == GimbalRollUUID
            {
                self.gimbalRollCharacteristic = (characteristic as! CBCharacteristic)
            }
            else if characteristic.UUID == DeviceNameUUID
            {
                self.deviceNameCharacteristic = (characteristic as! CBCharacteristic)
            }
            else if characteristic.UUID == BatteryUUID
            {
                self.batteryLevelCharacteristic = (characteristic as! CBCharacteristic)
                peripheral.setNotifyValue(true, forCharacteristic: self.batteryLevelCharacteristic)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!)
    {
        if (characteristic == self.batteryLevelCharacteristic)
        {
            batteryReadValue = 0
            if (batteryCount < 256)
            {
                batteryCount += 1
            }
            
            var data = characteristic.value
            var values = [UInt32](count:data.length, repeatedValue:0)
            data.getBytes(&values, length:data.length)
            
            batteryArray[index] = values[0]
            index++;
            if (index >= 256)
            {
                index = 0
            }
            
            for item in batteryArray
            {
                batteryReadValue += item
            }
            
            let floatBatteryValue = Float(batteryReadValue)
            
            
            batteryLevel = floatBatteryValue/batteryCount
            
            batteryLevel = (0.0011111111*batteryLevel - 2.666666667)*100
            // 3300 will be 100% and 2357 will be 0%
            println(batteryLevel)
        }
    }
    
    func writeSpeed(speed: UInt8)
    {
        if self.speedCharacteristic == nil {
            return;
        }
        
        var speedValue = speed
        let data = NSData(bytes: &speedValue, length: sizeof(UInt8))
        self.peripheral?.writeValue(data, forCharacteristic: self.speedCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
        
    }
    
    func writeModuleName(name: String) {
        
    }
    
    func writeGimbalOther(send_value: UInt16)
    {
        if self.gimbalOtherCharacteristic == nil
        {
            return
        }
        
        var gimbalOtherValue = send_value
        let data = NSData(bytes: &gimbalOtherValue, length: sizeof(UInt16))
        self.peripheral?.writeValue(data, forCharacteristic: self.gimbalOtherCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
    }
    
    func writeGimbalRoll(roll_value: UInt8)
    {
        if self.gimbalOtherCharacteristic == nil
        {
            return
        }
        
        var gimbalRollValue = roll_value
        let data = NSData(bytes: &gimbalRollValue, length: sizeof(UInt8))
        self.peripheral?.writeValue(data, forCharacteristic: self.gimbalRollCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
    }
    
    func sendBTServiceNotificationWithIsBluetoothConnected(isBluetoothConnected: Bool) {
        let connectionDetails = ["isConnected": isBluetoothConnected]
        NSNotificationCenter.defaultCenter().postNotificationName(BLEServiceChangedStatusNotification, object: self, userInfo: connectionDetails)
    }
    
}
