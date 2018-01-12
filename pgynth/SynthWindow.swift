//
//  SynthWindow.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 12/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation

import Cocoa

typealias Callback = (NSEvent) -> ()

class SynthWindow: NSWindow {
    var keyEventListeners = Array<Callback>()

    override func keyDown(with event: NSEvent) {
//        super.keyDown(with: event)
        for callback in keyEventListeners {
            callback(event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        for callback in keyEventListeners {
            callback(event)
        }
    }
    
    func addKeyEventCallback(callback: @escaping Callback) {
        keyEventListeners.append(callback)
    }
}
