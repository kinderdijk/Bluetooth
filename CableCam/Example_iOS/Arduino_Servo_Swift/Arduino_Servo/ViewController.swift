//
//  ViewController.swift
//  Arduino_Servo
//
//  Created by Owen L Brown on 9/24/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

import UIKit

class ViewController: UIViewController, AnalogStickProtocol {
    
    @IBOutlet weak var imgBluetoothStatus: UIImageView!
    @IBOutlet weak var positionSlider: UISlider!
    
    // Optional values are variables that can be nothing at all. nil in objective C is a pointer
    // to nothing, but nil in swift is the absence of a value of that type. If an optional does not
    // contain a value it will be set to nil.
    var timerTXDelay: NSTimer?
    var allowTX = true
    var lastPosition: UInt8 = 255
    
    let moveAnalogStick: AnalogStick = AnalogStick()
    
    override func viewDidLoad() {
        println("Test")
        super.viewDidLoad()
        let bgDiametr: CGFloat = 120
        let thumbDiametr: CGFloat = 60
        // Do any additional setup after loading the view, typically from a nib.
        
        // Rotate slider to vertical position
        let superView = self.positionSlider.superview
        positionSlider.removeFromSuperview()
        positionSlider.removeConstraints(self.view.constraints())
        positionSlider.setTranslatesAutoresizingMaskIntoConstraints(true)
        positionSlider.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        positionSlider.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 300.0)
        superView?.addSubview(self.positionSlider)
        positionSlider.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin | UIViewAutoresizing.FlexibleRightMargin
        positionSlider.center = CGPointMake(view.bounds.midX, view.bounds.midY)
        positionSlider.minimumValue = 0;
        positionSlider.maximumValue = 125;
        
        // Set thumb image on slider
        positionSlider.setThumbImage(UIImage(named: "Bar"), forState: UIControlState.Normal)
        
        let joysticksRadius = bgDiametr / 2
        moveAnalogStick.bgNodeDiametr = bgDiametr
        moveAnalogStick.thumbNodeDiametr = thumbDiametr
        moveAnalogStick.position = CGPointMake(joysticksRadius + 15, joysticksRadius + 15)
        moveAnalogStick.delagate = self
        // Cannot add SKNode to a uiview... This can only be added to an SKScene
        //superView?.addSubview(moveAnalogStick)
        
        // Watch Bluetooth connection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("connectionChanged:"), name: BLEServiceChangedStatusNotification, object: nil)
        
        // Start the Bluetooth discovery process
        btDiscoverySharedInstance
    }
    
    // MARK: AnalogStickProtocol
    func moveAnalogStick(analogStick: AnalogStick, velocity: CGPoint, angularVelocity: Float) {
        // Pass these values to the bluetooth module.
        // velocity.x is the movement in the x-direction.
        // velocity.y is the movement in the y-direction.
   
//        if let aN = appleNode {
//            if analogStick.isEqual(moveAnalogStick) {
//                aN.position = CGPointMake(aN.position.x + (velocity.x * 0.12), aN.position.y + (velocity.y * 0.12))
//            } else if analogStick.isEqual(rotateAnalogStick) {
//                aN.zRotation = CGFloat(angularVelocity)
//            }
//        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BLEServiceChangedStatusNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.stopTimerTXDelay()
    }
    
    @IBAction func positionSliderChanged(sender: UISlider) {
        self.sendPosition(UInt8(sender.value))
    }
    
    func connectionChanged(notification: NSNotification) {
        // Connection status changed. Indicate on GUI.
        let userInfo = notification.userInfo as [String: Bool]
        
        dispatch_async(dispatch_get_main_queue(), {
            // Set image based on connection status
            if let isConnected: Bool = userInfo["isConnected"] {
                if isConnected {
                    self.imgBluetoothStatus.image = UIImage(named: "Bluetooth_Connected")
                    
                    // Send current slider position
                    self.sendPosition(UInt8( self.positionSlider.value))
                } else {
                    self.imgBluetoothStatus.image = UIImage(named: "Bluetooth_Disconnected")
                }
            }
        });
    }
    
    func sendPosition(position: UInt8) {
        
        // Only allow communication after specified intervals.
        if !allowTX {
            return
        }
        
        // If the position is not valid or has not changed don't do anything.
        if position == lastPosition {
            return
        } else if ((position<0) || (position>125)) {
            return
        }
        
        // If the service is found, write the position.
        if let bleService = btDiscoverySharedInstance.bleService {
            bleService.writePosition(position)
            lastPosition = position
            
            // Once the position is written set the timer for the delay.
            // This does not allow a full range of motion. If the slider is moved too fast, the values do not update
            // like usual.
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
        self.sendPosition(UInt8(self.positionSlider.value))
    }
    
    func stopTimerTXDelay() {
        if self.timerTXDelay == nil {
            return
        }
        
        timerTXDelay?.invalidate()
        self.timerTXDelay = nil
    }
    
}

