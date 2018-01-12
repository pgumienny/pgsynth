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
var sounds: Set = [-1]
var waveType = 1

struct Synth {
    var outputUnit: AudioUnit? = nil
    var startingFrameCount: Double = 0
}

let semaphore = DispatchSemaphore(value: 1)

// MARK: Utility function
func CheckError(error: OSStatus, operation: String) {
    guard error != noErr else {
        return
    }
    
    print("Error: \(operation)")

    exit(1)
}

// MARK: Callback function
let SynthRenderProc: AURenderCallback = {(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
    var synth = inRefCon.assumingMemoryBound(to: Synth.self)
    
    var j = synth.pointee.startingFrameCount


    
    for frame in 0..<inNumberFrames {
        var buffers = UnsafeMutableAudioBufferListPointer(ioData)
        var value = Float32(0)
        semaphore.wait()
        for note in sounds {
            var sineFrequency = pow(2.0, Double(note)/12) * 440
            let cycleLength = 44100 / sineFrequency
            if waveType == 0 {
                value += Float32(sin(2 * .pi * (j / cycleLength))) / 12
            } else if waveType == 1 {
                value += Float32(Int(j) % Int(cycleLength)) / (12 * Float32(cycleLength))
            }
        }
        semaphore.signal()
        
        buffers![0].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        buffers![1].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        
        j += 1
    }

    synth.pointee.startingFrameCount = j
    return noErr
}

let keyPressCallback: Callback = {event -> () in
    var note = 0
    switch event.keyCode {
    case 0: // a
        note = 0
    case 1: // s
        note = 2
    case 2: // d
        note = 3
    case 3: // f
        note = 5
    case 5: // g
        note = 7
    case 4: // h
        note = 8
    case 38: // j
        note = 10
    case 40: // k
        note = 12
    case 37:
        note = 14
    case 41:
        note = 15
    case 39:
        note = 17
    case 42:
        note = 19
    default:
        note = 0
    }
    
    
    semaphore.wait()
    if event.type == NSEvent.EventType.keyDown {
        sounds.insert(note)
    }
    if event.type == NSEvent.EventType.keyUp {
        sounds.remove(note)
    }
    semaphore.signal()
    
    Swift.print("Caught a key down: \(event.keyCode)!")
}

func setUpSynth(synth: inout Synth){
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_DefaultOutput, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
    let comp = AudioComponentFindNext(nil, &outputcd)
    if comp == nil {
        print("Can't get output unit")
        exit(-1)
    }
    
    CheckError(error: AudioComponentInstanceNew(comp!, &synth.outputUnit),
               operation: "Couldn't open component for outputUnit")
    
    // Register the render callback
    var input = AURenderCallbackStruct(inputProc: SynthRenderProc, inputProcRefCon: &synth)
    
    CheckError(error: AudioUnitSetProperty(synth.outputUnit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
               operation: "AudioUnitSetProperty failed")
    
    // Initialize the unit
    CheckError(error: AudioUnitInitialize(synth.outputUnit!),
               operation: "Couldn't initialize output unit")
    
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var synth: Synth?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        sounds.remove(-1)
        let window:NSWindow? = NSApplication.shared.windows.first
        (window as! SynthWindow).addKeyEventCallback(callback: keyPressCallback)
        
        synth = Synth()
        setUpSynth(synth: &synth!)
        
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

