//
//  Filters.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 15/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation

protocol Filter {
    func filter(value: Float32) -> Float32
}

class LFF : Filter {
    var last_value: Float32 = 0.0
    var alpha: Float32
    var sR: Float32
    func setFrequency(frequency freq: Float32) {
        let dt = 1/sR
        alpha = dt / (dt + (1/freq))
        //                Swift.print("alpha = \(alpha)")
    }
    func filter(value: Float32) -> Float32 {
        let result = alpha * value + (1 - alpha) * last_value
        last_value = result
        return result
    }
    init(frequency freq_: Float32, samplingRate sR_: Float32) {
        sR = sR_
        alpha = 0
        self.setFrequency(frequency: freq_)
    }
}

class Overdrive : Filter {
    func filter(value: Float32) -> Float32 {
        if value > 0 {
            return 1 - expf(-value)
        } else {
            return -1 + expf(-value)
        }
    }
}
