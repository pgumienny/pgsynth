//
//  FFTView.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 17/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox
import AudioUnit
import CoreImage
import AppKit
import CoreGraphics

var fftview: FFTView?

class FFTView : NSImageView {
    var array:[UInt8] = []
    let width = 800
    let heigth = 400
    func update(data: [Float32], resolutionMultplier: Float32){
        array = Array(repeating: 255, count: 4*width*heigth)
        for i in 0..<width {
            for j in 0..<min(Int(data[i]), heigth) {
                array[((heigth - j - 1) * width + i) * 4 + 0] = 0
                array[((heigth - j - 1) * width + i) * 4 + 1] = 0
                array[((heigth - j - 1) * width + i) * 4 + 2] = 0
            }
        }
        DispatchQueue.main.async {
            self.draw()
        }
    }
    func draw(){
        let data = Data(bytes: array)
        let cimg = CIImage(bitmapData: data, bytesPerRow: 4*width, size: CGSize(width: width, height: heigth), format: kCIFormatRGBA8, colorSpace: nil)
    
        let bitmap = CIContext().createCGImage(cimg, from: cimg.extent)
    
        image = NSImage(cgImage: bitmap!, size: NSSize(width:width, height: heigth))
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        array = Array(repeating: 255, count: 4*width*heigth)
        self.draw()
        fftview = self
    }
    
}
