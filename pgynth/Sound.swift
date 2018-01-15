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
    init(pitch pitch_: Float32, startTime startTime_: Double, velocity velocity_: Float32, adsr adsr_: ADSR) {
        pitch = pitch_
        startTime = startTime_
        velocity = velocity_
        adsr = adsr_
        isDead = false
        shouldDelete = false
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

