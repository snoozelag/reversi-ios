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

enum NextTurn {
    /// 次の打ち手の番となった
    case change
    /// 次の打ち手はパス
    case pass
    /// ゲーム終了
    case gameOver
}

enum ComputerThinkingError: Error {
    case cancel
}

class Game {
    private(set) var board = Board()

    /// ゲーム終了状態か
    private(set) var isOver = false
    private(set) var turn: Disk = .dark
    var darkPlayer: Player = .manual
    var lightPlayer: Player = .manual
    var isComputerThinking = false

    func player(disk: Disk) -> Player {
        switch turn {
        case .dark:
            return darkPlayer
        case .light:
            return lightPlayer
        }
    }

    /// ターンを変更し、次の打ち手のパターンを返す
    func flipTurn() -> NextTurn {
        turn.flip()
        if board.validMoves(for: turn).isEmpty {
            if board.validMoves(for: turn.flipped).isEmpty {
                isOver = true
                try? save()
                return .gameOver
            } else {
                return .pass
            }
        } else {
            return .change
        }
    }

    /// コンピュータの実行可能なターンか
    func isComputerTurn(side: Disk? = nil) -> Bool {
        let side = side ?? turn
        return !isOver && side == turn && player(disk: side) == .computer
    }

    /// コンピュータの打ち手の結果を取得
    func getComputerTurnCoordinates(completion: @escaping (Result<[Coordinate], Error>) -> Void) {
        let disk = self.turn
        let coordinate = board.validMoves(for: disk).randomElement()!
        isComputerThinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.isComputerThinking {
                self.isComputerThinking = false
                let diskCoordinates = self.board.flippedDiskCoordinates(by: disk, at: coordinate)!
                completion(.success([coordinate] + diskCoordinates))
            } else {
                completion(.failure(ComputerThinkingError.cancel))
            }
        }
    }
}

// MARK: Save and Load

extension Game {

    private var path: String {
           (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
       }

    /// ゲームの状態をファイルに書き出し、保存します。
    func save() throws {
        var output: String = ""
        output += isOver ? Symbol.none.rawValue : Symbol(disk: turn).rawValue
        output += darkPlayer.rawValue.description
        output += lightPlayer.rawValue.description
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
        let players = try Disk.sides.reduce(into: [Player](), { result, side in
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = Player(rawValue: playerNumber)
                else {
                    throw FileIOError.read(path: path, cause: nil)
            }
            result.append(player)
        })

        self.darkPlayer = players[0]
        self.lightPlayer = players[1]

        let resultBoard = Board()
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
                    resultBoard.setDisk(disk, at: coordinate)
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
        self.board = resultBoard
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
