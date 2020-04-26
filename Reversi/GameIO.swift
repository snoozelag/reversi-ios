//
//  GameIO.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import UIKit

struct GameState {
    var turn: Disk = .dark
    var darkControlIndex: Int = 0
    var lightControlIndex: Int = 0
    var boardStates = [[BoardState]]()
}

struct BoardState {
    var disk: Disk?
    var coordinate: DiskCoordinate
}

class GameIO {

    private static var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    static func saveGame(gameState: GameState) throws {
        var output: String = ""
        output += DiskSymbol(disk: gameState.turn).rawValue
        output += String(gameState.darkControlIndex)
        output += String(gameState.lightControlIndex)
        output += "\n"
        output += getBoardStatesString(gameState.boardStates)

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    static private func getBoardStatesString(_ boardStates: [[BoardState]]) -> String {
        var output = ""
        for boardStatesInLine in boardStates {
            for boardState in boardStatesInLine {
                output += DiskSymbol(disk: boardState.disk).rawValue
            }
            output += "\n"
        }
        return output
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    static func loadGame() throws -> GameState {

        let input = try String(contentsOfFile: path, encoding: .utf8)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        let turn: Disk = try {
            guard let disk = line.popFirst().flatMap({  DiskSymbol(rawValue: String($0)) })?.disk else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return disk
        }()

        let darkPlayerIndex: Int = try {
            guard let playerTypeIndex = line.popFirst().flatMap({ PlayerTypeSymbol(rawValue: String($0)) })?.index else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerTypeIndex
        }()

        let lightPlayerIndex: Int = try {
            guard let playerTypeIndex = line.popFirst().flatMap({ PlayerTypeSymbol(rawValue: String($0)) })?.index else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerTypeIndex
        }()

        let boardStates: [[BoardState]] = try {
            var result = [[BoardState]]()
            var y = 0
            while let line = lines.popFirst() {
                var lineResult = [BoardState]()
                var x = 0
                for character in line {
                    guard let symbol = DiskSymbol(rawValue: "\(character)") else {
                        throw FileIOError.read(path: path, cause: nil)
                    }
                    let coordinate = DiskCoordinate(x: x, y: y)
                    let state = BoardState(disk: symbol.disk, coordinate: coordinate)
                    lineResult.append(state)
                    x += 1
                }
                guard x == BoardView.xCount else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                result.append(lineResult)
                y += 1
            }
            guard y == BoardView.yCount else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return result
        }()

        return GameState(turn: turn, darkControlIndex: darkPlayerIndex, lightControlIndex: lightPlayerIndex, boardStates: boardStates)
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

// MARK: File-private extensions

extension GameIO {

    private enum DiskSymbol: String {
        case dark = "x"
        case light = "o"
        case none = "-"

        init(disk: Disk?) {
            switch disk {
            case .dark:
                self = .dark
            case .light:
                self = .light
            default:
                self = .none
            }
        }

        var disk: Disk? {
            switch self {
            case .dark:
                return .dark
            case .light:
                return .light
            default:
                return nil
            }
        }
    }

    private enum PlayerTypeSymbol: String {
        case human = "0"
        case computer = "1"

        var index: Int {
            switch self {
            case .human:
                return 0
            case .computer:
                return 1
            }
        }
    }
}
