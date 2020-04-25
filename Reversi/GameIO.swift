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
    var boardStates = [BoardState]()
}

struct BoardState {
    var disk: Disk?
    var coordinate: DiskCoordinate
}

class GameIO {

    static let darkSymbol = "x"
    static let lightSymbol = "o"

    private static var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    /// TODO: 引数はあとで整理する
    static func saveGame(diskState: DiskState, boardStateString: String) throws {
        var output: String = ""
        output += (diskState.turn == .dark) ? darkSymbol : lightSymbol
        output += String(diskState.darkControlIndex)
        output += String(diskState.lightControlIndex)
        output += "\n"
        output += boardStateString

        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
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

            let darkPlayerIndex: Int = try {
                guard let darkPlayerSymbol = line.popFirst(),
                    let darkPlayerNumber = Int(darkPlayerSymbol.description),
                    let darkPlayer = PlayerType(rawValue: darkPlayerNumber) else {
                        throw FileIOError.read(path: path, cause: nil)
                }
                return darkPlayer.rawValue
                }()


            let lightPlayerIndex: Int = try {
                guard let lightPlayerSymbol = line.popFirst(),
                    let lightPlayerNumber = Int(lightPlayerSymbol.description),
                    let lightPlayer = PlayerType(rawValue: lightPlayerNumber) else {
                        throw FileIOError.read(path: path, cause: nil)
                }
                return lightPlayer.rawValue
                }()


            guard lines.count == BoardView.yCount else {
                throw FileIOError.read(path: path, cause: nil)
            }

            let boardStates: [BoardState] = try {
                var result = [BoardState]()
                var y = 0
                while let line = lines.popFirst() {
                    var x = 0
                    for character in line {
                        let disk = Disk(symbol: "\(character)")
                        result.append(BoardState(disk: disk, coordinate: DiskCoordinate(x: x, y: y)))
                        x += 1
                    }
                    guard x == BoardView.xCount else {
                        throw FileIOError.read(path: path, cause: nil)
                    }
                    y += 1
                }
                guard y == BoardView.yCount else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                return result
            }()

            return DiskState(turn: turn, darkControlIndex: darkPlayerIndex, lightControlIndex: lightPlayerIndex, boardStates: boardStates)
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
