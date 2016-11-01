//
//  ViewController.swift
//  CableCam
//
//  Created by Jon Pendlebury on 4/23/15.
//  Copyright (c) 2015 CaptureBeyondLimits. All rights reserved.
//

import UIKit
import SpriteKit

class SpeedViewController: UIViewController {

    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var centerButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    var mode = 0
    var skView: SKView!
    
    var lastSpeed : UInt8 = 0
    var scene : StickScene!
    
    var max_slider:Float = 200.0
    var stop_slider:Float = 100.0
    var min_slider:Float = 0.0
    
    var timerTXDelay: NSTimer?
    var allowTX = true
    
    var timerUpdateBattery: NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        println("////////////////////////////////////// Speedview controller loaded. /////////////////////////////////////")
        scene = StickScene(size: self.view.bounds.size)
        
        skView = self.view as! SKView
        skView.showsFPS = false
        skView.showsNodeCount = false
        /* Sprite Kit applies additional optimizations to improve rendering performance */
        skView.ignoresSiblingOrder = true
        
        skView.presentScene(scene)
        
        speedSlider.minimumValue = min_slider
        speedSlider.maximumValue = max_slider
        speedSlider.value = stop_slider
        speedSlider.setThumbImage(UIImage(named: "Slider"), forState: UIControlState.Normal)
        
        stopButton.layer.borderWidth = 1
        stopButton.layer.borderColor = UIColor.blackColor().CGColor
        
        settingsButton.setImage(UIImage(named: "Settings"), forState: UIControlState.Normal)
        
        // Add an observer to keep an eye on the connection.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("connectionChanged:"), name: BLEServiceChangedStatusNotification, object: nil)
        
        BluetoothInstance
//        comObject
        
        if timerUpdateBattery == nil {
            timerUpdateBattery = NSTimer.scheduledTimerWithTimeInterval(60.0, target: self, selector: Selector("timerUpdateBatteryElapsed"), userInfo: nil, repeats: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func connectionChanged(notification: NSNotification) {
        // Connection status changed. Indicate on GUI.
        println("Connection status changed.")
        let userInfo = notification.userInfo as! [String: Bool]
        
        dispatch_async(dispatch_get_main_queue(), {
            // Set image based on connection status
            if let isConnected: Bool = userInfo["isConnected"] {
                if isConnected {
                    println("///////// Connected /////////")
                    self.connectionLabel.text = "Connected"
                    
                    // Send current slider position
                    self.sendSpeed(UInt8( self.speedSlider.value))
                } else {
                    println("///////// Disconnected /////////")
                    self.connectionLabel.text = "Disconnected"
                }
            }
        });
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        if (sender.selectedSegmentIndex == 0) {
            mode = 0
        } else if (sender.selectedSegmentIndex == 1) {
            mode = 1
        }
    }
    
    @IBAction func sliderChanged(sender: UISlider) {
        if (sender.value <= stop_slider+4 && sender.value >= stop_slider-4) {
            sender.value = stop_slider
        }
        sendSpeed(UInt8(sender.value))
    }
    
    @IBAction func modeDependentExit(sender: UISlider) {
        if (mode == 1) {
            sender.value = stop_slider
            sendSpeed(UInt8(stop_slider))
        }
    }
    
    @IBAction func stopButtonPressed() {
        speedSlider.value = stop_slider
        sendSpeed(UInt8(stop_slider))
    }
    
    @IBAction func centerButtonPressed() {
        scene.centerGimbal();
    }
    
    func sendSpeed(speed: UInt8) {
        if !allowTX {
            return
        }
        
        if speed == lastSpeed || speed < 0 || speed > 200 {
            return
        }
        
        if let bleService = BluetoothInstance.bluetoothServices {
            bleService.writeSpeed(speed)
            lastSpeed = speed
            
            allowTX = false
            if timerTXDelay == nil {
                timerTXDelay = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("timerTXDelayElapsed"), userInfo: nil, repeats: false)
            }
        }
    }
    
    func timerTXDelayElapsed() {
        self.allowTX = true
        self.stopTimerTXDelay()
        
        // Send current slider position
        self.sendSpeed(UInt8(self.speedSlider.value))
    }
    
    func stopTimerTXDelay() {
        if self.timerTXDelay == nil {
            return
        }
        
        timerTXDelay?.invalidate()
        self.timerTXDelay = nil
    }
    
    func timerUpdateBatteryElapsed() {
        let str = BluetoothInstance.bluetoothServices?.batteryLevel
        batteryLabel.text = String(format: "%.1f", str!)
    }
}

