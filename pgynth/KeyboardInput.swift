//
//  KeyboardInput.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 15/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation
import Cocoa
import CoreAudio
import AudioToolbox
import AudioUnit

typealias Callback = (Synth, NSEvent) -> ()

let keyPressCallback: Callback = {synth, event -> () in
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
    synth.semaphore.wait()
    if event.type == NSEvent.EventType.keyDown {
        if synth.sounds[note] == nil || (synth.sounds[note]?.isDead)! {
            var s = Sound(pitch: Float32(pow(2.0, Double(note)/12)) * 110, startTime: synth.currentTime, velocity: 1, adsr: synth.adsr)
            synth.sounds[note] = s
        }
    }
    if event.type == NSEvent.EventType.keyUp {
        synth.sounds[note]?.isDead = true
        synth.sounds[note]?.startTime = synth.currentTime
    }
    synth.semaphore.signal()
    
    //    Swift.print("Caught a key: \(event.keyCode)!")
}
