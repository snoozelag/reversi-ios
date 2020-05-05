//
//  Board.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/05/05.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

public class Board {
    var lines: [[Squire]]

    /// 盤の幅（ `8` ）を表します。
    public static let width: Int = 8

    /// 盤の高さ（ `8` ）を返します。
    public static let height: Int = 8

    init() {
        self.lines = {
            var result = [[Squire]]()
            for y in 0..<Self.height {
                var line = [Squire]()
                for x in 0..<Self.width {
                    line.append(Squire(disk: nil, coordinate: Coordinate(x: x, y: y)))
                }
                result.append(line)
            }
            return result
        }()
        self.reset()
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        guard (0..<Board.width) ~= coordinate.x && (0..<Board.height) ~= coordinate.y else { return }
        lines[coordinate.y][coordinate.x].disk = disk
    }

    func disk(at coordinate: Coordinate) -> Disk? {
        guard (0..<Board.width) ~= coordinate.x && (0..<Board.height) ~= coordinate.y else { return nil }
        return lines[coordinate.y][coordinate.x].disk
    }

    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    func countDisks(of side: Disk) -> Int {
        var count = 0

        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let coordinate = Coordinate(x: x, y: y)
                if disk(at: coordinate) == side {
                    count +=  1
                }
            }
        }

        return count
    }

    /// 盤上に置かれたディスクの枚数が多い方の色を返します。
    /// 引き分けの場合は `nil` が返されます。
    /// - Returns: 盤上に置かれたディスクの枚数が多い方の色です。引き分けの場合は `nil` を返します。
    func sideWithMoreDisks() -> Disk? {
        let darkCount = countDisks(of: .dark)
        let lightCount = countDisks(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }

    func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, at coordinate: Coordinate) -> [Coordinate] {

        guard self.disk(at: coordinate) == nil else {
            return []
        }

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

        var diskCoordinates: [Coordinate] = []

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine: [Coordinate] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                switch (disk, self.disk(at: Coordinate(x: x, y: y))) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append(Coordinate(x: x, y: y))
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }

    /// `x`, `y` で指定されたセルに、 `disk` が置けるかを調べます。
    /// ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要があります。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: 指定されたセルに `disk` を置ける場合は `true` を、置けない場合は `false` を返します。
    func canPlaceDisk(_ disk: Disk, at coordinate: Coordinate) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate).isEmpty
    }

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    func validMoves(for side: Disk) -> [Coordinate] {
        var coordinates: [Coordinate] = []

        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let coordinate = Coordinate(x: x, y: y)
                if canPlaceDisk(side, at: coordinate) {
                    coordinates.append(coordinate)
                }
            }
        }

        return coordinates
    }

    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    func reset() {
        for line in lines {
            for squire in line {
                setDisk(nil, at: squire.coordinate)
            }
        }

        setDisk(.light, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2 - 1))
        setDisk(.dark, at: Coordinate(x: Board.width / 2, y: Board.height / 2 - 1))
        setDisk(.dark, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2))
        setDisk(.light, at: Coordinate(x: Board.width / 2, y: Board.height / 2))
    }
}

struct DiskPlacementError: Error {
    let disk: Disk
    let x: Int
    let y: Int
}
