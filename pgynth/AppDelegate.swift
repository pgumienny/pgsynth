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

var synth: Synth?


struct Synth {
    var outputUnit: AudioUnit? = nil
    var startingFrameCount: Double = 0
    var sounds = [UInt8: Sound]()
    var waveType = 1
    var currentTime: Double = 0
    let SamplingRate = 44100
    var adsr : ADSR = ADSR()
}

struct ADSR {
    var attackTime: Double = 0.05
    var decayTime: Double = 0.1
    var releaseTime: Double = 0.3
    var attackValue: Double = 2.5
}


var midiPort = MIDIPortRef()
var midiClient = MIDIClientRef()

let midiCallback: MIDIReadProc = { (pktlist, synthRef, srcConnRefCon) -> Void in
    var synth = synthRef?.assumingMemoryBound(to: Synth.self)
    var packets = pktlist.pointee
    Swift.print("midi incoming")
    
    let packet:MIDIPacket = packets.packet
    
    var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
    ap.initialize(to:packet)
    
    for _ in 0 ..< packets.numPackets {
        let p = ap.pointee
        
        handleNote(note: p, synthPointer: synth)
        
        ap = MIDIPacketNext(ap)
    }
    
}

func handleNote( note:MIDIPacket, synthPointer: UnsafeMutablePointer<Synth>?) {
//    var synth = synthPointer!.pointee
    print("timestamp \(note.timeStamp)", terminator: "")
    let operationType = note.data.0 & 0xF0
    let noteNumber = note.data.1
    let velocity = note.data.2
    
    semaphore.wait()
    if operationType == 0x80 ||  (operationType == 0x90 && velocity == 0) {
        synth!.sounds[noteNumber]?.isDead = true
        synth!.sounds[noteNumber]?.startTime = synth!.currentTime
    } else if operationType == 0x90 {
        if synth!.sounds[noteNumber] == nil || (synth!.sounds[noteNumber]?.isDead)! {
            Swift.print("adding new note")
            let pitch = pow(2.0, (Double(noteNumber) - 69)/12) * 440
            let s = Sound(pitch: pitch, startTime: synth!.currentTime, velocity: Double(velocity)/255)
            Swift.print("sounds.cout: \(synth!.sounds.count))!")
            Swift.print("sound pitch: \(pitch)")
            synth!.sounds[noteNumber] = s
        }
    }

    semaphore.signal()
    
    var hex = String(format:"0x%X", note.data.0)
    print(" \(hex)", terminator: "")
    hex = String(format:"0x%X", note.data.1)
    print(" \(hex)", terminator: "")
    hex = String(format:"0x%X", note.data.2)
    print(" \(hex)")
}

func initMidi() {
    MIDIClientCreate("pgclient" as CFString, nil, nil, &midiClient)
    MIDIInputPortCreate(midiClient, "pgport" as CFString, midiCallback, &synth, &midiPort)
    
    if MIDIGetNumberOfSources() == 0 {
        Swift.print("no external midi devices connected")
        return
    }
    
    Swift.print("connecting MIDI")
    
    MIDIPortConnectSource(midiPort, MIDIGetSource(0), nil)
}

class Sound: NSObject {
    var pitch: Double
    var startTime: Double
    var isDead: Bool
    var velocity: Double
    var shouldDelete: Bool
    init(pitch pitch_: Double, startTime startTime_: Double, velocity velocity_: Double) {
        pitch = pitch_
        startTime = startTime_
        velocity = velocity_
        isDead = false
        shouldDelete = false
    }
    
    func getEnvelopeHelper(time: Double) -> Double {
        let deltaTime = time - startTime
        let adsr = synth!.adsr
        if !isDead {
            if deltaTime < adsr.attackTime {
              return adsr.attackValue * deltaTime / adsr.attackTime
            }
            if deltaTime < adsr.decayTime + adsr.attackTime {
                let tmpDelta = deltaTime - adsr.attackTime
                return 1 + (adsr.attackValue - 1) *  (adsr.decayTime - tmpDelta) / adsr.decayTime
            } else {
                return 1
            }
        } else {
            if deltaTime < adsr.releaseTime {
                return (adsr.releaseTime - deltaTime) / adsr.releaseTime
            } else {
                shouldDelete = true
                return 0
            }

        }
    }
    func getEnvelope(time: Double) -> Double {
        return self.velocity * getEnvelopeHelper(time: time)
    }
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
    synth.pointee.currentTime = Double(j) / Double(synth.pointee.SamplingRate)
    
    for frame in 0..<inNumberFrames {
        var buffers = UnsafeMutableAudioBufferListPointer(ioData)
        var value = Float32(0)
        semaphore.wait()
        for (note, sound) in synth.pointee.sounds {
            var sineFrequency = sound.pitch
            let cycleLength = Double(synth.pointee.SamplingRate) / sineFrequency
            if synth.pointee.waveType == 0 {
                value += Float32(sound.getEnvelope(time: synth.pointee.currentTime)) * Float32(sin(2 * .pi * (j / cycleLength))) / 12
            } else if synth.pointee.waveType == 1 {
                value += Float32(sound.getEnvelope(time: synth.pointee.currentTime)) * Float32(Int(j) % Int(cycleLength)) / (20 * Float32(cycleLength))
            }
//            if Int(j) % 1000 == 0 {
//                Swift.print("currenTime: \(currentTime))!")
//                Swift.print("soundtie: \(sound.startTime - currentTime))!")
//                Swift.print("Env val: \(sound.getEnvelope(time: currentTime))!")
//            }
        }
        synth.pointee.sounds = synth.pointee.sounds.filter({ (key: UInt8, value: Sound) -> Bool in
            value.shouldDelete == false
        })
        
//
//        if Int(j) % 1000 == 0 {
//            Swift.print("sounds.cout: \(sounds.count))!")
//        }
        
        semaphore.signal()
        
        buffers![0].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        buffers![1].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        
        j += 1
        synth.pointee.currentTime = Double(j) / Double(synth.pointee.SamplingRate)
    }

    synth.pointee.startingFrameCount = j
    return noErr
}

let keyPressCallback: Callback = {event -> () in
    var note: UInt8 = 0
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
    case 37: // l
        note = 14
    case 41: // ;
        note = 15
    case 39: // '
        note = 17
    case 42: // \
        note = 19
    default:
        note = 255
    }
    
    if note == 255 {
        return
    }
    semaphore.wait()
    if event.type == NSEvent.EventType.keyDown {
        if synth!.sounds[note] == nil || (synth!.sounds[note]?.isDead)! {
            var s = Sound(pitch: pow(2.0, Double(note)/12) * 110, startTime: synth!.currentTime, velocity: 1)
            synth!.sounds[note] = s
        }
    }
    if event.type == NSEvent.EventType.keyUp {
        synth!.sounds[note]?.isDead = true
        synth!.sounds[note]?.startTime = synth!.currentTime
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
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window:NSWindow? = NSApplication.shared.windows.first
        (window as! SynthWindow).addKeyEventCallback(callback: keyPressCallback)
        
        initMidi()
        
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

