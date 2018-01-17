//
//  AppDelegate.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 12/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Cocoa
import CoreAudio
import AudioToolbox
import AudioUnit

var windowRef: NSWindow? = nil


// MARK: Utility function
func CheckError(error: OSStatus, operation: String) {
    guard error != noErr else {
        return
    }
    
    print("Error: \(operation)")

    exit(1)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var synth: Synth?
    var midiC: MIDIController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window:NSWindow? = NSApplication.shared.windows.first
        windowRef = window
        synth = Synth()
        setUpSynth(synth: &synth!)
        midiC = MIDIController(synth_: &synth!)
        
        (window as! SynthWindow).addKeyEventCallback(callback: keyPressCallback, context_: synth!)
        
        // Start playing
        CheckError(error: AudioOutputUnitStart(synth!.outputUnit!),
                   operation: "Couldn't start output unit")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        AudioOutputUnitStop(synth!.outputUnit!)
        AudioUnitUninitialize(synth!.outputUnit!)
        AudioComponentInstanceDispose(synth!.outputUnit!)
    }


}

