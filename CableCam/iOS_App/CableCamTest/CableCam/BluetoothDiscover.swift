//
//  BluetoothDiscover.swift
//  CableCam
//
//  Created by Jon Pendlebury on 4/25/15.
//  Copyright (c) 2015 CaptureBeyondLimits. All rights reserved.
//

import Foundation
import CoreBluetooth

let BluetoothInstance = BluetoothDiscover()

class BluetoothDiscover: NSObject, CBCentralManagerDelegate {
    
    private var centralManager: CBCentralManager?
    private var cableCamPeripheral: CBPeripheral?
    
    internal var foundDevices = [CBPeripheral]()
    
    override init() {
        super.init()
        
        println("///// Initialized Bluetooth discovery.")
        let centralqueue = dispatch_queue_create("cableCam", DISPATCH_QUEUE_SERIAL)
        
        // Initalize the central manager.
        // The first function that is called when this finished is the DidUpdateState function.
        centralManager = CBCentralManager(delegate: self, queue: centralqueue)
    }
    
    func startScanning() {
        // Determine if the central manager is initialized properly.
        println("Start scanning for peripherals.")
        if let central = centralManager {
            // Scan for all advertising devices. A list of services can be added to the first argument
            // and the scanner will only look for peripherals with those specific devices.
            central.scanForPeripheralsWithServices([BLEServiceUUID, CBUUID(string: "1800")], options: nil);
        }
    }
    
    var bluetoothServices: BluetoothServices? {
        didSet {
            if let service = self.bluetoothServices {
                service.startDiscoveringServices()
            }
        }
    }
    
    // Central Manager Delegate Methods
    // These four methods are required to conform to the central manager delegate.
    
    // When the scanning is started and a peripheral with the required types is found this method is called.
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        if (peripheral.name == nil) {
            return
        }
        
        // Make sure the peripheral is setup properly, and actually exists.
        if (peripheral==nil || peripheral.name=="" || peripheral.name==nil) {
            return
        }
        
        println("Discovered peripheral with required services.")
        // Make sure we are not already connected to another peripheral.
        if (cableCamPeripheral==nil || cableCamPeripheral?.state == CBPeripheralState.Disconnected) {
            
            foundDevices.append(peripheral)
            
            // The peripheral must be retained before a connection can be made.
            self.cableCamPeripheral = peripheral
            
            self.bluetoothServices = nil
            
            // If this is the peripheral we want, attempt a connection.
            central.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        // Make sure the peripheral exists.
        if (peripheral == nil) {
            return
        }
        
        // If the peripheral is still the one we had before...
        if (peripheral == self.cableCamPeripheral) {
            self.bluetoothServices = BluetoothServices(initWithPeripheral: peripheral)
        }
        
        println("Connected to peripheral.")
        // Now that we have a connection, stop scanning for new devices
        central.stopScan()
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        // Make sure the peripheral exists
        println("Disconnecting from peripheral.")
        if (error != nil) {
            println("ERROR:   \(error.description)")
        }
        
        if (peripheral == nil) {
            return;
        }
        
        // If it is our peripheral
        if (peripheral == self.cableCamPeripheral) {
            self.cableCamPeripheral = nil
            self.bluetoothServices = nil
        }
        
        self.startScanning()
    }
    
    // Determine the state the Bluetooth on the ios device.
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        switch (central.state) {
        case CBCentralManagerState.Unsupported:
            // The device does not support bluetooth.
            println("This device does not support the correct version of Bluetooth.")
            break
            
        case CBCentralManagerState.Unknown:
            // The status of the bluetooth is unknown and an update is iminent.
            // The bast thing to do is wait for another update.
            break
            
        case CBCentralManagerState.Resetting:
            // The device experienced an issue and an update is iminent.
            break
            
        case CBCentralManagerState.Unauthorized:
            // The platform is not authorized to use bluetooth.
            println("This device is not authorized to use Bluetooth.")
            break
            
        case CBCentralManagerState.PoweredOff:
            // Bluetooth is powered off and not ready to use.
            println("The Bluetooth on this device is powered off.")
            break
            
        case CBCentralManagerState.PoweredOn:
            // Bluetooth is power on and ready to use.
            self.startScanning()
            break
        }
    }
    
}