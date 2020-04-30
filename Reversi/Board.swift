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

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    func validMoveCoordinates(for side: Disk) -> [DiskCoordinate]? {
        var coordinates = [DiskCoordinate]()
        for line in lines {
            for squire in line {
                let placing = SquireState(disk: side, coordinate: squire.coordinate)
                // ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要がある
                let canPlaceDisk = !flippedDiskCoordinates(by: placing).isEmpty
                if canPlaceDisk {
                    coordinates.append(squire.coordinate)
                }
            }
        }
        return coordinates.isEmpty ? nil : coordinates
    }

    func flippedDiskCoordinates(by placing: SquireState) -> [DiskCoordinate] {

        let isNotPresent = (squireAt(placing.coordinate)!.disk == nil)
        guard isNotPresent else {
            return []
        }

        var diskCoordinates = [DiskCoordinate]()

        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]

        for direction in directions {
            var x = placing.coordinate.x
            var y = placing.coordinate.y

            var diskCoordinatesInLine = [DiskCoordinate]()
            flipping: while true {
                x += direction.x
                y += direction.y

                if let directionDisk = squireAt(DiskCoordinate(x: x, y: y))?.disk {
                    switch (placing.disk!, directionDisk) { // Uses tuples to make patterns exhaustive
                    case (.dark, .dark), (.light, .light):
                        diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                        break flipping
                    case (.dark, .light), (.light, .dark):
                        diskCoordinatesInLine.append(DiskCoordinate(x: x, y: y))
                    }
                } else {
                    break
                }

            }
        }

        return diskCoordinates
    }

    func hasNextTurn(_ turn: Disk) -> NextTurnResult {
        if let coordinates = validMoveCoordinates(for: turn) {
            // 今回の打ち手がある
            return .valid(coordinates)
        } else if let coordinates = validMoveCoordinates(for: turn.flipped) {
            // 次回の打ち手はある
            return .pass(coordinates)
        } else {
            // 両者ない
            return .end
        }
    }
}

enum NextTurnResult {
    case valid([DiskCoordinate])
    case pass([DiskCoordinate])
    case end
}
