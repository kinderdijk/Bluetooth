//
//  SettingViewController.swift
//  CableCam
//
//  Created by Jon Pendlebury on 6/13/15.
//  Copyright (c) 2015 CaptureBeyondLimits. All rights reserved.
//

import UIKit

class SettingViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var pitchSlider: UISlider!
    var camName: String = "";
    
    var timerTXDelay: NSTimer?
    var allowTX = true
    var lastPitch : UInt8 = 0
    
    var max_slider:Float = 200.0
    var stop_slider:Float = 100.0
    var min_slider:Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.nameField.delegate = self
        
        pitchSlider.minimumValue = min_slider
        pitchSlider.maximumValue = max_slider
        pitchSlider.value = stop_slider
        pitchSlider.setThumbImage(UIImage(named: "Slider"), forState: UIControlState.Normal)
        
//        BluetoothInstance
    }
    
    @IBAction func backButtonPressed() {
        if (!nameField.text.isEmpty) {
            camName = nameField.text
            println("Device name: " + camName)
            
            sendName(camName)
        }
    }
    
    @IBAction func sliderChanged(sender: UISlider) {
        sendPitch(UInt8(sender.value))
    }
    
    func sendName(deviceName: String) {
        
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.view.endEditing(true)
        
        sendName(textField.text)
        
        return false
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newLength = count(textField.text.utf16) + count(string.utf16) - range.length
        return newLength <= 20 // Bool
    }
    
    func sendPitch(pitch: UInt8) {
        if !allowTX {
            return
        }
        
        if pitch == lastPitch || pitch < 0 || pitch > 200 {
            return
        }
        
        if let bleService = BluetoothInstance.bluetoothServices {
            bleService.writeGimbalRoll(pitch)
            lastPitch = pitch
            
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
        self.sendPitch(UInt8(self.pitchSlider.value))
    }
    
    func stopTimerTXDelay() {
        if self.timerTXDelay == nil {
            return
        }
        
        timerTXDelay?.invalidate()
        self.timerTXDelay = nil
    }
}