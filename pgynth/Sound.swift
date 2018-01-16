//
//  Sound.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 15/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation

struct ADSR {
    var attackTime: Double = 0.05
    var decayTime: Double = 0.1
    var releaseTime: Double = 0.3
    var attackValue: Double = 2.5
}

class Sound: NSObject {
    var pitch: Float32
    var startTime: Double
    var isDead: Bool
    var velocity: Float32
    var adsr: ADSR
    var shouldDelete: Bool
    var waveType: Int
    var filters: [Filter]
    init(pitch pitch_: Float32, startTime startTime_: Double, velocity velocity_: Float32, adsr adsr_: ADSR, waveType waveType_: Int) {
        filters = []
        filters.append(LFF(frequency: pitch_ * 8, samplingRate: 44100))
        pitch = pitch_
        startTime = startTime_
        velocity = velocity_
        adsr = adsr_
        isDead = false
        shouldDelete = false
        waveType = waveType_
    }
    
    func getSoundValue(time: Double) -> Float32 {
        var value:Float = 0
        let cycleLength = Double(44100) / Double(pitch)
        let j = time * Double(44100)
        if waveType & 1 > 0 {
            value += Float32(getEnvelope(time: time)) * Float32(sin(2 * .pi * (j / cycleLength))) / 12
        }
        if waveType & 2 > 0 {
            value += Float32(getEnvelope(time: time)) * Float32(Int(j) % Int(cycleLength)) / (20 * Float32(cycleLength))
        }
        if waveType & 4 > 0 {
            var val = -1
            if Int(j) % Int(cycleLength) < Int(cycleLength/4) {
                val = 1
            }
            value += Float32(getEnvelope(time: time)) * Float32(val) / 20
        }
        for filter in filters {
            value = filter.filter(value: value)
        }
        return value
    }
    
    func getEnvelopeHelper(time: Double) -> Double {

        let deltaTime = time - startTime
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
//                Swift.print("killing")
                shouldDelete = true
                return 0
            }
            
        }
    }
    func getEnvelope(time: Double) -> Float32 {
        return self.velocity * Float32(getEnvelopeHelper(time: time))
    }
}

