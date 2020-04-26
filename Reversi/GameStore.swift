//
//  GameStore.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import UIKit

class GameStore {

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }

    private static var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    static func saveGame(gameState: GameState) throws {
        var output: String = ""
        output += DiskSymbol(disk: gameState.turn).rawValue
        output += String(gameState.darkPlayerType.rawValue)
        output += String(gameState.lightPlayerType.rawValue)
        output += "\n"
        output += getString(lines: gameState.board.lines)

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    static func loadGame() throws -> GameState {

        let input = try String(contentsOfFile: path, encoding: .utf8)
        var linesString: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var lineString = linesString.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        let lines = try getLines(linesString: linesString)

        let turn: Disk = try {
            guard let disk = lineString.popFirst().flatMap({ DiskSymbol(rawValue: String($0)) })?.disk else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return disk
        }()

        let darkPlayerType: PlayerType = try {
            guard let playerIndexString = lineString.popFirst().flatMap({ String($0) }),
                let playerType = Int(playerIndexString).flatMap({ PlayerType(rawValue: $0) }) else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerType
        }()

        let lightPlayerType: PlayerType = try {
            guard let playerIndexString = lineString.popFirst().flatMap({ String($0) }),
                let playerType = Int(playerIndexString).flatMap({ PlayerType(rawValue: $0) }) else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return playerType
        }()

        return GameState(turn: turn, darkPlayerType: darkPlayerType, lightPlayerType: lightPlayerType, board: Board(lines: lines))
    }

    /// 盤面配列から文字列に変換
    private static func getString(lines: [[SquireState]]) -> String {
        var output = ""
        for line in lines {
            for squire in line {
                output += DiskSymbol(disk: squire.disk).rawValue
            }
            output += "\n"
        }
        return output
    }

    /// 文字列から盤面配列を取り出し
    private static func getLines(linesString: ArraySlice<Substring>) throws -> [[SquireState]] {
        var lines = [[SquireState]]()
        for (y, lineString) in linesString.enumerated() {
            var line = [SquireState]()
            for (x, squireCharacter) in lineString.enumerated() {
                guard let symbol = DiskSymbol(rawValue: String(squireCharacter)) else {
                      throw FileIOError.read(path: path, cause: nil)
                }
                let coordinate = DiskCoordinate(x: x, y: y)
                let squire = SquireState(disk: symbol.disk, coordinate: coordinate)
                line.append(squire)
            }
            guard line.count == Board.xCount else {
                throw FileIOError.read(path: path, cause: nil)
            }
            lines.append(line)
        }
        guard lines.count == Board.yCount else {
            throw FileIOError.read(path: path, cause: nil)
        }
        return lines
    }
}

// MARK: File-private extensions

extension GameStore {

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
}
