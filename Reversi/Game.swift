//
//  Game.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/05/05.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

enum Player: Int {
    case manual = 0
    case computer = 1
}

class Game {
    var isOver = false
    var turn: Disk = .dark
    var players: [Player] = [.manual, .manual]
    var board = Board()
}

// MARK: Save and Load

extension Game {

    private var path: String {
           (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
       }

    /// ゲームの状態をファイルに書き出し、保存します。
    func save() throws {
        var output: String = ""
        output += Symbol(disk: turn).rawValue
        for side in Disk.sides {
            output += players[side.index].rawValue.description
        }
        output += "\n"

        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let coordinate = Coordinate(x: x, y: y)
                let disk = board.disk(at: coordinate)
                output += Symbol(disk: disk).rawValue
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
    func load() throws {
        let input = try String(contentsOfFile: path, encoding: .utf8)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        do { // turn
            guard
                let diskSymbol = line.popFirst()
                else {
                    throw FileIOError.read(path: path, cause: nil)
            }
            if let disk = Symbol(rawValue: diskSymbol.description)?.disk {
                turn = disk
            } else {
                isOver = true
            }
        }

        // players
        for side in Disk.sides {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = Player(rawValue: playerNumber)
                else {
                    throw FileIOError.read(path: path, cause: nil)
            }
            players[side.index] = player
        }

        let loadingBoard = Board()
        do { // board
            guard lines.count == Board.height else {
                throw FileIOError.read(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let symbol = Symbol(rawValue: "\(character)")
                    let disk = symbol?.disk
                    let coordinate = Coordinate(x: x, y: y)
                    loadingBoard.setDisk(disk, at: coordinate)
                    x += 1
                }
                guard x == Board.width else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                y += 1
            }
            guard y == Board.height else {
                throw FileIOError.read(path: path, cause: nil)
            }
        }
        self.board = loadingBoard
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }

    private enum Symbol: String {
        case dark = "x"
        case light = "o"
        case none = "-"

        init(disk: Disk?) {
            switch disk {
            case .dark:
                self = .dark
            case .light:
                self = .light
            case nil:
                self = .none
            }
        }

        var disk: Disk? {
            switch self {
            case .dark:
                return .dark
            case .light:
                return .light
            case .none:
                return nil
            }
        }
    }
}
