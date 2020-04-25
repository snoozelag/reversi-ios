//
//  GameIO.swift
//  Reversi
//
//  Created by teruto.yamasaki on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import UIKit

struct DiskState {
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

    private static let darkSymbol = "x"
    private static let lightSymbol = "o"
    private static let noneSymbol = "-"

    private static var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    /// TODO: 引数はあとで整理する
    static func saveGame(diskState: DiskState) throws {
        var output: String = ""
        output += (diskState.turn == .dark) ? darkSymbol : lightSymbol
        output += String(diskState.darkControlIndex)
        output += String(diskState.lightControlIndex)
        output += "\n"
        output += getBoardStatesString(diskState.boardStates)

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    static func getBoardStatesString(_ boardStates: [[BoardState]]) -> String {
        var output = ""
        for boardStatesInLine in boardStates {
            for boardState in boardStatesInLine {
                if let disk = boardState.disk {
                    switch disk {
                    case .dark:
                        output += GameIO.darkSymbol
                    case .light:
                        output += GameIO.lightSymbol
                    }
                } else {
                    output += GameIO.noneSymbol
                }
            }
            output += "\n"
        }
        return output
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    static func loadGame() throws
        -> DiskState {

            let input = try String(contentsOfFile: path, encoding: .utf8)
            var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

            guard var line = lines.popFirst() else {
                throw FileIOError.read(path: path, cause: nil)
            }

            let turn: Disk = try {
                guard let diskSymbol = line.popFirst(), let disk = Disk(symbol: diskSymbol.description) else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                return disk
            }()

            let darkPlayerIndex = try playerTypeForSymbol(line.popFirst()).rawValue
            let lightPlayerIndex = try playerTypeForSymbol(line.popFirst()).rawValue

            guard lines.count == BoardView.yCount else {
                throw FileIOError.read(path: path, cause: nil)
            }

            let boardStates: [[BoardState]] = try {
                var result = [[BoardState]]()
                var y = 0
                while let line = lines.popFirst() {
                    var lineResult = [BoardState]()
                    var x = 0
                    for character in line {
                        let disk = Disk(symbol: "\(character)")
                        let coordinate = DiskCoordinate(x: x, y: y)
                        let state = BoardState(disk: disk, coordinate: coordinate)
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

            return DiskState(turn: turn, darkControlIndex: darkPlayerIndex, lightControlIndex: lightPlayerIndex, boardStates: boardStates)
    }

    private static func playerTypeForSymbol(_ playerSymbol: Substring.Element?) throws -> PlayerType {
        guard let playerSymbol = playerSymbol,
            let playerNumber = Int(playerSymbol.description),
            let playerType = PlayerType(rawValue: playerNumber) else {
                throw FileIOError.read(path: path, cause: nil)
        }
        return playerType
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }

}

// MARK: File-private extensions

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

    init(index: Int) {
        for side in Disk.allCases {
            if index == side.index {
                self = side
                return
            }
        }
        preconditionFailure("Illegal index: \(index)")
    }

    var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}
