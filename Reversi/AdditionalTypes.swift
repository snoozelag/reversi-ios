//
//  AdditionalTypes.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

// MARK: Additional types

struct GameState {
    var turn: Disk = .dark
    var darkPlayerType: PlayerType = .human
    var lightPlayerType: PlayerType = .human
    var board = Board()
}

struct SquireState {
    var disk: Disk?
    var coordinate: DiskCoordinate
}

enum PlayerType: Int {
    case human = 0
    case computer = 1
}

final class Canceller {
    private(set) var isCancelled: Bool = false
    private let body: (() -> Void)?

    init(_ body: (() -> Void)?) {
        self.body = body
    }

    func cancel() {
        if isCancelled { return }
        isCancelled = true
        body?()
    }
}

struct DiskPlacementError: Error {
    let disk: Disk
    let coordinate: DiskCoordinate
}


