//
//  BTDiscovery.swift
//  Arduino_Servo
//
//  Created by Owen L Brown on 9/24/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

let btDiscoverySharedInstance = BTDiscovery();

class BTDiscovery: NSObject, CBCentralManagerDelegate {
    
    private let centralManager: CBCentralManager?
    private var peripheralBLE: CBPeripheral?
    
    override init() {
        super.init()
        println("Start")
        
        let centralQueue = dispatch_queue_create("com.raywenderlich", DISPATCH_QUEUE_SERIAL)
        // When you initialize the central manager, begin the process.
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    // Called when the state of the BLE device is determined.
    func startScanning() {
        println("Start scanning")
        if let central = centralManager {
            central.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
        }
    }
    
    var bleService: BTService? {
        didSet {
            if let service = self.bleService {
                service.startDiscoveringServices()
            }
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    // When a peripheral with the defined services is found this method is called.
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        // Be sure to retain the peripheral or it will fail during connection.
        
        // Validate peripheral information
        if ((peripheral == nil) || (peripheral.name == nil) || (peripheral.name == "")) {
            return
        }
        
        // If not already connected to a peripheral, then connect to this one
        if ((self.peripheralBLE == nil) || (self.peripheralBLE?.state == CBPeripheralState.Disconnected)) {
            // Retain the peripheral before trying to connect
            self.peripheralBLE = peripheral
            
            // Reset service
            self.bleService = nil
            
            // Connect to peripheral
            central.connectPeripheral(peripheral, options: nil)
        }
    }
    
    // When a peripheral is detected this method is called.
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("Got here.")
        if (peripheral == nil) {
            return;
        }
        
        // Create new service class
        if (peripheral == self.peripheralBLE) {
            self.bleService = BTService(initWithPeripheral: peripheral)
        }
        
        // Stop scanning for new devices
        central.stopScan()
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
        if (peripheral == nil) {
            return;
        }
        
        // See if it was our peripheral that disconnected
        if (peripheral == self.peripheralBLE) {
            self.bleService = nil;
            self.peripheralBLE = nil;
        }
        
        // Start scanning for new devices
        self.startScanning()
    }
    
    // MARK: - Private
    
    func clearDevices() {
        self.bleService = nil
        self.peripheralBLE = nil
    }
    
    // First function called when the central manager is initialized.
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        switch (central.state) {
        case CBCentralManagerState.PoweredOff:
            self.clearDevices()
            
        case CBCentralManagerState.Unauthorized:
            // Indicate to user that the iOS device does not support BLE.
            println("State Unauthorized")
            break
            
        case CBCentralManagerState.Unknown:
            println("State Unknown")
            // Wait for another event
            break
            
        case CBCentralManagerState.PoweredOn:
            self.startScanning()
            
        case CBCentralManagerState.Resetting:
            self.clearDevices()
            
        case CBCentralManagerState.Unsupported:
            println("State Unsupported")
            break
            
        default:
            break
        }
    }
    
}
