//
//  GameIO.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import UIKit

class GameIO {

    private static var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    /// TODO: 引数はあとで整理する
    static func saveGame(turn: Disk, playerControls: [UISegmentedControl], boardView: BoardView) throws {
        var output: String = ""
        output += turn.symbol
        for side in Disk.allCases {
            output += playerControls[side.index].selectedSegmentIndex.description
        }
        output += "\n"

        let noneSymbol = "-"
        for y in boardView.yRange {
            for x in boardView.xRange {
                output += boardView.diskAt(x: x, y: y)?.symbol ?? noneSymbol
            }
            output += "\n"
        }

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    static func loadGame(boardView: BoardView, playerControls: [UISegmentedControl]) throws
        -> (turn: Disk, playerControls: [UISegmentedControl]) {

        // TODO: あとで消す
        var turn: Disk

        let input = try String(contentsOfFile: path, encoding: .utf8)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        do { // turn
            guard
                let diskSymbol = line.popFirst(),
                let disk = Disk(symbol: diskSymbol.description)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            turn = disk
        }

        // players
        for side in Disk.allCases {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = Player(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            playerControls[side.index].selectedSegmentIndex = player.rawValue
        }

        do { // board
            guard lines.count == boardView.height else {
                throw FileIOError.read(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Disk(symbol: "\(character)")
                    boardView.setDisk(disk, atX: x, y: y, animated: false)
                    x += 1
                }
                guard x == boardView.width else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                y += 1
            }
            guard y == boardView.height else {
                throw FileIOError.read(path: path, cause: nil)
            }
        }

        return (turn, playerControls)
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }

}

extension Disk {

    init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .dark
        case "o":
            self = .light
        default:
            return nil
        }
    }

    fileprivate var symbol: String {
        switch self {
        case .dark:
            return "x"
        case .light:
            return "o"
        }
    }
}
