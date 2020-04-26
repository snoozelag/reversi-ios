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
    var board = Board()
}

struct SquireState {
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
        output += getSquireStatesString(lines: gameState.board.lines)

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    static private func getSquireStatesString(lines: [[SquireState]]) -> String {
        var output = ""
        for line in lines {
            for squire in line {
                output += DiskSymbol(disk: squire.disk).rawValue
            }
            output += "\n"
        }
        return output
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    static func loadGame() throws -> GameState {

        let input = try String(contentsOfFile: path, encoding: .utf8)
        var linesString: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var lineString = linesString.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        let turn: Disk = try {
            guard let disk = lineString.popFirst().flatMap({  DiskSymbol(rawValue: String($0)) })?.disk else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return disk
        }()

        let darkPlayerIndex: Int = try {
            guard let playerTypeIndex = lineString.popFirst().flatMap({ PlayerTypeSymbol(rawValue: String($0)) })?.index else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerTypeIndex
        }()

        let lightPlayerIndex: Int = try {
            guard let playerTypeIndex = lineString.popFirst().flatMap({ PlayerTypeSymbol(rawValue: String($0)) })?.index else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerTypeIndex
        }()

        let lines = try getLines(linesString: linesString)

        return GameState(turn: turn, darkControlIndex: darkPlayerIndex, lightControlIndex: lightPlayerIndex, board: Board(lines: lines))
    }

    private static func getLines(linesString: ArraySlice<Substring>) throws -> [[SquireState]] {
        var linesString = linesString
        var lines = [[SquireState]]()
        var y = 0
        while let lineString = linesString.popFirst() {
            var line = [SquireState]()
            var x = 0
            for character in lineString {
                guard let symbol = DiskSymbol(rawValue: "\(character)") else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                let coordinate = DiskCoordinate(x: x, y: y)
                let squire = SquireState(disk: symbol.disk, coordinate: coordinate)
                line.append(squire)
                x += 1
            }
            guard x == Board.xCount else {
                throw FileIOError.read(path: path, cause: nil)
            }
            lines.append(line)
            y += 1
        }
        guard y == Board.yCount else {
            throw FileIOError.read(path: path, cause: nil)
        }
        return lines
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
