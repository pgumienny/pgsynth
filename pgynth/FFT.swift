//
//  FFT.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 16/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox
import AudioUnit
import CoreImage

// TODO
// display the result
// verify results


struct complex {
    var r: Float32
    var i: Float32
    
    func abs() -> Float32 {
        return sqrtf(r * r + i * i)
    }
}

func i_exp(i: Float32) -> complex {
    return complex(r: cosf(i), i: sinf(i))
}

extension complex {
    static func + (left: complex, right: complex) -> complex {
        return complex(r: left.r + right.r, i: left.i + right.i)
    }
    static func - (left: complex, right: complex) -> complex {
        return complex(r: left.r - right.r, i: left.i - right.i)
    }
    static func * (left: complex, right: complex) -> complex {
        return complex(r: left.r * right.r - left.i * right.i, i: left.i * right.r + left.r * right.i)
    }
}


class FFT {
    var buffer: [Float32]
    var result: [complex]
    var tmp: [complex]
    let FFT_size = 8192
    var bitmap: CGImage
    let semaphore = DispatchSemaphore(value: 1)
    let concurrencyLimitingSemaphore = DispatchSemaphore(value: 1)
    init(){
        buffer = []
        result = []
        tmp = Array(repeating: complex(r: 0.0, i: 0.0), count: FFT_size/2)
        let cgrect = CGRect(x: 300, y: 300, width: 300, height: 300)
        bitmap = CIContext().createCGImage(CIImage(color: CIColor.black), from: cgrect)!
    }
    
    func push_value(v: Float32) {
        semaphore.wait()
        buffer.append(v)
        semaphore.signal()
    }
    
    func push_values(v: [Float32]) {
        semaphore.wait()
        buffer.append(contentsOf: v)
        semaphore.signal()
    }
    
    func separate(offset: Int, n: Int) {
        for i in 0..<n/2 {
            tmp[i] = result[offset + 2 * i + 1]
        }
        for i in 0..<n/2 {
            result[offset + i] = result[offset + 2 * i]
        }
        for i in 0..<n/2 {
            result[offset + i + n/2] = tmp[i]
        }
    }
    
    func fft_helper(offset: Int, n: Int) {
        if n < 2 {
            return
        } else {
            separate(offset: offset, n: n)
            fft_helper(offset: offset, n: n/2)
            fft_helper(offset: offset + n/2, n: n/2)
            for k in 0..<n/2 {
                let e = result[offset + k]
                let o = result[offset + k + n/2]
                let w = i_exp(i: -2.0 * Float.pi * Float(k) / Float(n))
                result[offset + k] = e + w * o
                result[offset + k + n/2] = e - w * o
            }
        }
    }
    
    func calculateFFT() {
        concurrencyLimitingSemaphore.wait()
        result = [complex]()
        semaphore.wait()
        for i in 0..<FFT_size {
            result.append(complex(r: buffer[i], i: 0))
        }
        buffer.removeSubrange(0..<FFT_size)
        semaphore.signal()
        DispatchQueue.global(qos: .userInitiated).async {
//            let start = DispatchTime.now()
            self.fft_helper(offset: 0, n: self.FFT_size)
//            let end = DispatchTime.now()
//            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
//            let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
            
//            print("Time to calculate FFT =  \(timeInterval) seconds")
            
            
    //        Swift.print("\(result[10].abs()) \(result[20].abs()) \(result[30].abs()) \(result[40].abs()) \(result[50].abs())")
//            var max: Float32 = 0
//            var max_i: Int = 0
//            for i in 0..<self.FFT_size {
//                if self.result[i].abs() > max {
//                    max_i = i
//                    max = self.result[i].abs()
//                }
//            }
//            Swift.print("\(Float(max_i)*44100/Float32(self.FFT_size))")
            self.concurrencyLimitingSemaphore.signal()
        }
        
    }
    func isFFTReady() -> Bool {
        semaphore.wait()
        let ret = buffer.count >= FFT_size
        semaphore.signal()
        return ret
    }
    
}

