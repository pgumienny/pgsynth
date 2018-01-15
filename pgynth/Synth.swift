//
//  Synth.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 15/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox
import AudioUnit

class Synth {
    var outputUnit: AudioUnit? = nil
    var startingFrameCount: Double = 0
    var sounds = [UInt8: Sound]()
    var waveType = 6
    var currentTime: Double = 0
    var lastValue: Float32 = 0
    let SamplingRate = 44100
    var adsr : ADSR = ADSR()
    var lff = LFF(frequency: 10000, samplingRate: 44100)
    var overdrive = Overdrive()
    let semaphore = DispatchSemaphore(value: 1)
    
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


let SynthRenderProc: AURenderCallback = {(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
    var synth = inRefCon.assumingMemoryBound(to: Synth.self)
    
    var j = synth.pointee.startingFrameCount
    synth.pointee.currentTime = Double(j) / Double(synth.pointee.SamplingRate)
    for frame in 0..<inNumberFrames {
        var buffers = UnsafeMutableAudioBufferListPointer(ioData)
        var value = Float32(0)
        synth.pointee.semaphore.wait()
        for (note, sound) in synth.pointee.sounds {
            var sineFrequency = sound.pitch
            let cycleLength = Double(synth.pointee.SamplingRate) / Double(sineFrequency)
            if synth.pointee.waveType & 1 > 0 {
                value += Float32(sound.getEnvelope(time: synth.pointee.currentTime)) * Float32(sin(2 * .pi * (j / cycleLength))) / 12
            }
            if synth.pointee.waveType & 2 > 0 {
                value += Float32(sound.getEnvelope(time: synth.pointee.currentTime)) * Float32(Int(j) % Int(cycleLength)) / (20 * Float32(cycleLength))
            }
            if synth.pointee.waveType & 4 > 0 {
                var val = -1
                if Int(j) % Int(cycleLength) < Int(cycleLength/4) {
                    val = 1
                }
                value += Float32(sound.getEnvelope(time: synth.pointee.currentTime)) * Float32(val) / 20
            }
        }
        synth.pointee.sounds = synth.pointee.sounds.filter({ (key: UInt8, value: Sound) -> Bool in
            value.shouldDelete == false
        })
        
        synth.pointee.semaphore.signal()
        
        //        value = synth.lff.filter(value: value)
        //        value = synth.pointee.overdrive.filter(value: value)
        
        buffers![0].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        buffers![1].mData?.assumingMemoryBound(to: Float32.self)[Int(frame)] = value
        
        j += 1
        synth.pointee.currentTime = j / Double(synth.pointee.SamplingRate)
    }
    
    synth.pointee.startingFrameCount = j
    return noErr
}

