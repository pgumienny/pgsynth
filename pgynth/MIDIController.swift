//
//  MIDIController.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 15/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox
import AudioUnit


class MIDIController {
    var synth: Synth
    var midiPort : MIDIPortRef
    var midiClient : MIDIClientRef
    init(synth_: inout Synth) {
        midiPort = MIDIPortRef()
        midiClient = MIDIClientRef()
        synth = synth_
        MIDIClientCreate("pgclient" as CFString, nil, nil, &midiClient)
        MIDIInputPortCreate(midiClient, "pgport" as CFString, midiCallback, &synth, &midiPort)
        
        if MIDIGetNumberOfSources() == 0 {
            Swift.print("no external midi devices connected")
            return
        }
        
        Swift.print("connecting MIDI")
        
        MIDIPortConnectSource(midiPort, MIDIGetSource(0), nil)
    }
}



let midiCallback: MIDIReadProc = { (pktlist, synthRef, srcConnRefCon) -> Void in
    var synth = synthRef?.assumingMemoryBound(to: Synth.self)
    var packets = pktlist.pointee
//    Swift.print("midi incoming")
    
    let packet:MIDIPacket = packets.packet
    
    var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
    ap.initialize(to:packet)
    synth!.pointee.semaphore.wait()
    for _ in 0 ..< packets.numPackets {
        let p = ap.pointee
        
        handleNote(note: p, synth: synth)
        
        ap = MIDIPacketNext(ap)
    }
    synth!.pointee.semaphore.signal()
}

func handleNote( note:MIDIPacket, synth: UnsafeMutablePointer<Synth>?) {
    
//    print("timestamp \(note.timeStamp)", terminator: "")
    let operationType = note.data.0 & 0xF0
    let noteNumber = note.data.1
    let velocity = note.data.2
    
    
    if operationType == 0x80 ||  (operationType == 0x90 && velocity == 0) {
        synth!.pointee.sounds[noteNumber]?.isDead = true
        synth!.pointee.sounds[noteNumber]?.startTime = synth!.pointee.currentTime
    } else if operationType == 0x90 {
        if synth!.pointee.sounds[noteNumber] == nil || (synth!.pointee.sounds[noteNumber]?.isDead)! {
            let pitch = Float32(pow(2.0, (Double(noteNumber) - 69)/12)) * 440
            let s = Sound(pitch: pitch, startTime: synth!.pointee.currentTime, velocity: Float32(velocity)/255, adsr: synth!.pointee.adsr, waveType: 6)
//            Swift.print("sounds.cout: \(synth!.pointee.sounds.count))!")
//            Swift.print("sound pitch: \(pitch)")
            synth!.pointee.sounds[noteNumber] = s
        }
    }
    
    if operationType == 0xB0 && noteNumber == 0x7 {
        //        synth!.lff.setFrequency(frequency: 100 + 30 * Float32(velocity))
    }
//    
//    var hex = String(format:"0x%X", note.data.0)
//    print(" \(hex)", terminator: "")
//    hex = String(format:"0x%X", note.data.1)
//    print(" \(hex)", terminator: "")
//    hex = String(format:"0x%X", note.data.2)
//    print(" \(hex)")
    
    
}

