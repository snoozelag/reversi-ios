//
//  Board.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/30.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

struct DiskPlacementError: Error {
    let disk: Disk
    let coordinate: Coordinate
}

class Board {

    var lines = [[Squire]]()

    /// 盤の幅（ `8` ）を表します。
    public static let width: Int = 8

    /// 盤の高さ（ `8` ）を返します。
    public static let height: Int = 8

    init() {
        self.lines = {
            var result = [[Squire]]()
            for y in (0..<Board.height) {
                var line = [Squire]()
                for x in (0..<Board.width) {
                    line.append(Squire(disk: nil, coordinate: Coordinate(x: x, y: y)))
                }
                result.append(line)
            }
            return result
        }()
    }
    
    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    func countDisks(of side: Disk) -> Int {
        var count = 0
        for y in 0..<Self.height {
            for x in 0..<Self.width {
                if lines[y][x].disk == side {
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

        guard lines[coordinate.y][coordinate.x].disk == nil else {
            return []
        }

        var diskCoordinates = [Coordinate]()

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine = [Coordinate]()
            flipping: while true {
                x += direction.x
                y += direction.y

                guard (0..<Board.width) ~= x && (0..<Board.height) ~= y else {
                    break flipping
                }
                switch (disk, lines[y][x].disk) { // Uses tuples to make patterns exhaustive
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
        var coordinates = [Coordinate]()

        for y in 0..<Self.height {
            for x in 0..<Self.width {
                let coordinate = Coordinate(x: x, y: y)
                if canPlaceDisk(side, at: coordinate) {
                    coordinates.append(coordinate)
                }
            }
        }

        return coordinates
    }

    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset() {
        for y in 0..<Board.height {
            for x in  0..<Board.width {
                setDisk(nil, at: Coordinate(x: x, y: y))
            }
        }

        setDisk(.light, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2 - 1))
        setDisk(.dark, at: Coordinate(x: Board.width / 2, y: Board.height / 2 - 1))
        setDisk(.dark, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2))
        setDisk(.light, at: Coordinate(x: Board.width / 2, y: Board.height / 2))
    }

    /// `x`, `y` で指定されたセルの状態を、与えられた `disk` に変更します。
    /// `animated` が `true` の場合、アニメーションが実行されます。
    /// アニメーションの完了通知は `completion` ハンドラーで受け取ることができます。
    /// - Parameter disk: セルに設定される新しい状態です。 `nil` はディスクが置かれていない状態を表します。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter animated: セルの状態変更を表すアニメーションを表示するかどうかを指定します。
    /// - Parameter completion: アニメーションの完了通知を受け取るハンドラーです。
    ///     `animated` に `false` が指定された場合は状態が変更された後で即座に同期的に呼び出されます。
    ///     ハンドラーが受け取る `Bool` 値は、 `UIView.animate()`  等に準じます。
    public func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        lines[coordinate.y][coordinate.x].disk = disk
    }

    /// `x`, `y` で指定されたセルに `disk` を置きます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter isAnimated: ディスクを置いたりひっくり返したりするアニメーションを表示するかどうかを指定します。
    /// - Parameter completion: アニメーション完了時に実行されるクロージャです。
    ///     このクロージャは値を返さず、アニメーションが完了したかを示す真偽値を受け取ります。
    ///     もし `animated` が `false` の場合、このクロージャは次の run loop サイクルの初めに実行されます。
    /// - Throws: もし `disk` を `x`, `y` で指定されるセルに置けない場合、 `DiskPlacementError` を `throw` します。
    func placeDisk(_ disk: Disk, at coordinate: Coordinate) throws -> ([Coordinate], [PlaceType]) {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, coordinate: coordinate)
        }
        let placeTypes = diskCoordinates.map { setDisk(disk, coordinate: $0) }
        return (diskCoordinates, placeTypes)
    }


    func setDisk(_ disk: Disk?, coordinate: Coordinate) -> PlaceType {
        var squire = lines[coordinate.x][coordinate.y]
        let diskBefore: Disk? = squire.disk
        squire.disk = disk
        let diskAfter: Disk? = squire.disk
        lines[coordinate.x][coordinate.y] = squire

        switch (diskBefore, diskAfter) {
        case (.none, .none):
            return .none
        case (.none, .some(let diskAfter)):
            return .set(diskAfter)
        case (.some(let diskBefore), .none):
            return .remove(diskBefore)
        case (.some(let diskBefore), .some(let diskAfter)):
            return .flip(diskBefore, diskAfter)
        }
    }
    
}

enum PlaceType {
    case none
    case set(_ after: Disk)
    case remove(_ before: Disk)
    case flip(_ before: Disk, _ after: Disk)
}
