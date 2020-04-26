//
//  Board.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/26.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

class Board {
    /// 盤の幅（ `8` ）
    static let xCount: Int = 8
    /// 盤の高さ（ `8` ）
    static let yCount: Int = 8

    private(set) var lines = [[SquireState]]()

    init() {
        lines = self.clear()
    }

    /// まったくコマが置いてない状態
    private func clear() -> [[SquireState]] {
        var lines = [[SquireState]]()
        for y in 0..<Board.yCount {
            var line = [SquireState]()
            for x in 0..<Board.xCount {
                let boardState = SquireState(disk: nil, coordinate: DiskCoordinate(x: x, y: y))
                line.append(boardState)
            }
            lines.append(line)
        }
        return lines
    }

    /// 真ん中あたりにコマを四つおた状態
    func reset() {
        lines = clear()

        let initialBoardStates: [SquireState] = [
            SquireState(disk: .light, coordinate: DiskCoordinate(x: Board.xCount / 2 - 1, y: Board.yCount / 2 - 1)),
            SquireState(disk: .dark, coordinate: DiskCoordinate(x: Board.xCount / 2, y: Board.yCount / 2 - 1)),
            SquireState(disk: .dark, coordinate: DiskCoordinate(x: Board.xCount / 2 - 1, y: Board.yCount / 2)),
            SquireState(disk: .light, coordinate: DiskCoordinate(x: Board.xCount / 2, y: Board.yCount / 2))
        ]

        initialBoardStates.forEach({
            var squire = lines[$0.coordinate.y][$0.coordinate.x]
            squire.disk = $0.disk
            lines[$0.coordinate.y][$0.coordinate.x] = squire
        })
    }

    func diskAt(_ coordinate: DiskCoordinate) {

    }
}
