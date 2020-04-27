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
        lines = self.initialLines()
    }

    init(lines: [[SquireState]]) {
        self.lines = lines
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
    private func initialLines() -> [[SquireState]] {
        var lines = clear()

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
        return lines
    }

    func setDisk(squire: SquireState) {
        lines[squire.coordinate.y][squire.coordinate.x] = squire
    }

    func setDisks(squires: [SquireState]) {
        squires.forEach { squire in
            lines[squire.coordinate.y][squire.coordinate.x] = squire
        }
    }

    func setDisks(coordinates: [DiskCoordinate], to disk: Disk) {
        coordinates.forEach { coordinate in
            lines[coordinate.y][coordinate.x] = SquireState(disk: disk, coordinate: coordinate)
        }
    }

    func squireAt(_ coordinate: DiskCoordinate) -> SquireState? {
        guard coordinate.y >= 0, coordinate.x >= 0, coordinate.y < Board.xCount, coordinate.x < Board.yCount else { return nil }
        return lines[coordinate.y][coordinate.x]
    }

    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    func countDisks(of side: Disk) -> Int {
        var count = 0
        for line in lines {
            for squire in line {
                if squire.disk == side {
                    count +=  1
                }
            }
        }
        return count
    }

}
