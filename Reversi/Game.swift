//
//  Game.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/30.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

class Game {
    var isOver = false
    var turn: Disk = .dark
    var darkPlayer: PlayerType = .manual
    var lightPlayer: PlayerType = .manual
    var board = Board()

    var turnPlayerType: PlayerType {
        switch turn {
        case .dark:
            return darkPlayer
        case .light:
            return lightPlayer
        }
    }
}

extension Game {

    private var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態を初期化し、新しいゲームを開始します。
    func new() {
        board.reset()
        turn = .dark
        darkPlayer = .manual
        lightPlayer = .manual
        try? save()
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    func save() throws {
        var output: String = ""
        let diskForSymbol = isOver ? nil : turn
        output += Symbol(disk: diskForSymbol).rawValue
        for playerIndex in [darkPlayer.rawValue, lightPlayer.rawValue] {
            output += playerIndex.description
        }
        output += "\n"

        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let diskOnSquire = board.lines[y][x].disk
                output += Symbol(disk: diskOnSquire).rawValue
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
                let diskSymbolString = line.popFirst()?.description,
                let disk = Symbol(rawValue: diskSymbolString)?.disk
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            turn = disk
        }

        // players
        darkPlayer = try {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let loadedPlayer = PlayerType(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return loadedPlayer
        }()

        lightPlayer = try {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let loadedPlayer = PlayerType(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return loadedPlayer
        }()

        do { // board
            guard lines.count == Board.height else {
                throw FileIOError.read(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Symbol(rawValue: character.description)?.disk
                    let coordinate = Coordinate(x: x, y: y)
                    board.setDisk(disk, at: coordinate)
                    board.lines[y][x] = Squire(disk: disk, coordinate: coordinate)
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
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

enum PlayerType: Int, CaseIterable {
    case manual = 0
    case computer = 1
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
