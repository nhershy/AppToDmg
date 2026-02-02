//
//  SoundPlayer.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import AppKit

class SoundPlayer {
    static func playSuccessJingle() {
        NSSound(named: "Glass")?.play()
    }
}
