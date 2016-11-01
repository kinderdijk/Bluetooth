//
//  GameScene.swift
//  stick test
//
//  Created by Dmitriy Mitrophanskiy on 28.09.14.
//  Copyright (c) 2014 Dmitriy Mitrophanskiy. All rights reserved.
//

import SpriteKit

class StickScene: SKScene, AnalogStickProtocol {
    var appleNode: SKSpriteNode?
    let moveAnalogStick: AnalogStick = AnalogStick()
    let rotateAnalogStick: AnalogStick = AnalogStick()
    
    weak var viewController : SpeedViewController!
    
    var timerTXDelay: NSTimer?
    var allowTX = true
    var previousCombined: UInt16 = 0;
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        let bgDiametr: CGFloat = 120
        let thumbDiametr: CGFloat = 60
        let joysticksRadius = bgDiametr / 2
        self.backgroundColor = UIColor.whiteColor()
        
        moveAnalogStick.bgNodeDiametr = bgDiametr
        moveAnalogStick.thumbNodeDiametr = thumbDiametr
        moveAnalogStick.position = CGPointMake(CGRectGetMaxX(self.frame) - joysticksRadius - 15, joysticksRadius + 15)
        moveAnalogStick.delagate = self
        self.addChild(moveAnalogStick)
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        /* Called when a touch begins */
        super.touchesBegan(touches as Set<NSObject>, withEvent: event)
        if let touch = touches.first as? UITouch {
            appleNode?.position = touch.locationInNode(self)
        }
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
    
    // MARK: AnalogStickProtocol
    func moveAnalogStick(analogStick: AnalogStick, velocity: CGPoint, angularVelocity: Float) {
        var xInt:Int8 = Int8(velocity.x)
        var yInt:Int8 = Int8(velocity.y)
        
        var xUint:UInt16 = UInt16(velocity.x+61)
        println("X: \(xUint)")
        var yUint:UInt16 = UInt16(velocity.y+61)
        println("Y: \(yUint)")
        
        if xUint <= 121 && xUint > 1 && yUint <= 121 && yUint > 1
        {
            var combined:UInt16 = 0x0 | xUint
            combined = combined << 8
            combined = combined | yUint
            
            sendGimbalOther(combined)
        }
    }
    
    func centerGimbal() {
        moveAnalogStick.reset()
        moveAnalogStick(moveAnalogStick, velocity: CGPointZero, angularVelocity: 0.0)
    }
    
    func sendGimbalOther(gimbalOther: UInt16) {
        if !allowTX {
            return
        }
        
        if gimbalOther == previousCombined {
            return
        }
        
        if let bleService = BluetoothInstance.bluetoothServices {
            bleService.writeGimbalOther(gimbalOther)
            previousCombined = gimbalOther
            
            allowTX = false
            if timerTXDelay == nil {
                timerTXDelay = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("timerTXDelayElapsed"), userInfo: nil, repeats: false)
            }
        }
    }
    
    func timerTXDelayElapsed() {
        self.allowTX = true
        self.stopTimerTXDelay()
    }
    
    func stopTimerTXDelay() {
        if self.timerTXDelay == nil {
            return
        }
        
        timerTXDelay?.invalidate()
        self.timerTXDelay = nil
    }
}
