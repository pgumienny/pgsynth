//
//  SynthWindow.swift
//  pgynth
//
//  Created by Przemyslaw Gumienny on 12/01/2018.
//  Copyright © 2018 pg. All rights reserved.
//

import Foundation

import Cocoa

class SynthWindow: NSWindow {
    var context : Synth?
    var keyEventListeners = Array<Callback>()

    override func keyDown(with event: NSEvent) {
//        super.keyDown(with: event)
        for callback in keyEventListeners {
            callback(context!, event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        for callback in keyEventListeners {
            callback(context!, event)
        }
    }
    
    func addKeyEventCallback(callback: @escaping Callback, context_: Synth) {
        context = context_
        keyEventListeners.append(callback)
    }
}
