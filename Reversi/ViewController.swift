import UIKit

struct DiskCoordinate {
    var x: Int
    var y: Int
}

class ViewController: UIViewController {

    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var darkPlayerControl: UISegmentedControl!
    @IBOutlet private var lightPlayerControl: UISegmentedControl!
    @IBOutlet private var darkCountLabel: UILabel!
    @IBOutlet private var lightCountLabel: UILabel!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!

    /// どちらの色のプレイヤーのターンかを表します。ゲーム終了時は `nil` です。
    private var turn: Disk = .dark
    private var animationCanceller: Canceller?
    private var isAnimating: Bool { animationCanceller != nil }
    private var playerCancellers: [Disk: Canceller] = [:]
    private var viewHasAppeared: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        
        do {
            let gameState = try GameIO.loadGame()
            setupViews(gameState: gameState)
        } catch _ {
            newGame()
        }

        updateMessageViews(side: turn)
        darkCountLabel.text = "\(boardView.countDisks(of: .dark))"
        lightCountLabel.text = "\(boardView.countDisks(of: .light))"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewHasAppeared {
            viewHasAppeared = true
            waitForPlayer()
        }
    }

    private func setupViews(gameState: GameState) {
        turn = gameState.turn
        darkPlayerControl.selectedSegmentIndex = gameState.darkControlIndex
        lightPlayerControl.selectedSegmentIndex = gameState.lightControlIndex
        gameState.boardStates.forEach({ boardStatesInLine in
            boardStatesInLine.forEach({
                boardView.setDisk($0.disk, at: $0.coordinate, animated: false)
            })
        })
    }

    // MARK: - Inputs

    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
    @IBAction private func pressResetButton(_ sender: UIButton) {
        showResetGameDialog()
    }

    @IBAction private func darkPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let player = PlayerType(rawValue: sender.selectedSegmentIndex)!
        changePlayer(side: .dark, player: player)
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let player = PlayerType(rawValue: sender.selectedSegmentIndex)!
        changePlayer(side: .light, player: player)
    }

    // MARK: - Views

    /// 現在のターンをメッセージラベルに表示
    private func updateMessageViews(side: Disk) {
        messageDiskView.isHidden = false
        messageDiskView.disk = side
        messageLabel.text = "'s turn"
    }

    /// ゲームの結果をメッセージラベルに表示
    private func updateMessageViewsForGameEnd() {
        let darkCount = boardView.countDisks(of: .dark)
        let lightCount = boardView.countDisks(of: .light)
        if darkCount == lightCount {
            // 引き分けを表示
            messageDiskView.isHidden = true
            messageLabel.text = "Tied"
        } else {
            // 勝者を表示
            let winner: Disk = (darkCount > lightCount) ? .dark : .light
            messageDiskView.isHidden = false
            messageDiskView.disk = winner
            messageLabel.text = " won"
        }
    }

    // MARK: - Alert

    /// リセットダイアログ
    private func showResetGameDialog() {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.resetGame()
        })
        present(alertController, animated: true)
    }

    /// パス
    private func showPassDialog() {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.nextTurn()
        })
        present(alertController, animated: true)
    }

    /// 人間、コンピュータを変更
    private func changePlayer(side: Disk, player: PlayerType) {

        try? GameIO.saveGame(gameState: GameState(turn: turn,
                                                  darkControlIndex: darkPlayerControl.selectedSegmentIndex,
                                                  lightControlIndex: lightPlayerControl.selectedSegmentIndex,
                                                  boardStates: boardView.getBoardStates()))

        if let canceller = playerCancellers[side] {
            canceller.cancel()
        }

        if !isAnimating, side == turn, case .computer = player {
            playTurnOfComputer()
        }
    }

    /// ゲームのリセット
    private func resetGame() {
        animationCanceller?.cancel()
        animationCanceller = nil

        for side in Disk.allCases {
            playerCancellers[side]?.cancel()
            playerCancellers.removeValue(forKey: side)
        }

        newGame()
        waitForPlayer()
    }

    // MARK: Game management

    /// ゲームの状態を初期化し、新しいゲームを開始します。
    private func newGame() {
        boardView.reset()
        turn = .dark

        darkPlayerControl.selectedSegmentIndex = PlayerType.human.rawValue
        lightPlayerControl.selectedSegmentIndex = PlayerType.human.rawValue

        try? GameIO.saveGame(gameState: GameState(turn: turn,
                                                  darkControlIndex: darkPlayerControl.selectedSegmentIndex,
                                                  lightControlIndex: lightPlayerControl.selectedSegmentIndex,
                                                  boardStates: boardView.getBoardStates()))
    }

    /// プレイヤーの行動を待ちます。
    private func waitForPlayer() {
        let playerControl = (turn == .dark) ? darkPlayerControl : lightPlayerControl
        switch PlayerType(rawValue: playerControl!.selectedSegmentIndex)! {
        case .human:
            break
        case .computer:
            playTurnOfComputer()
        }
    }

    /// プレイヤーの行動後、そのプレイヤーのターンを終了して次のターンを開始します。
    /// もし、次のプレイヤーに有効な手が存在しない場合、パスとなります。
    /// 両プレイヤーに有効な手がない場合、ゲームの勝敗を表示します。
    private func nextTurn() {

        turn.flip()

        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                updateMessageViewsForGameEnd()
            } else {
                updateMessageViews(side: turn)
                showPassDialog()
            }
        } else {
            updateMessageViews(side: turn)
            waitForPlayer()
        }
    }

    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    private func playTurnOfComputer() {
        let coordinate = validMoves(for: turn).randomElement()!

        playerActivityIndicators[turn.rawValue].startAnimating()

        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[self.turn.rawValue].stopAnimating()
            self.playerCancellers[self.turn] = nil
        }
        let canceller = Canceller(cleanUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            try! self.placeDisk(self.turn, at: coordinate, animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }

        playerCancellers[turn] = canceller
    }

    // MARK: - Reversi logics

    private func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, at coordinate: DiskCoordinate) -> [DiskCoordinate] {
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

        guard boardView.diskAt(coordinate) == nil else {
            return []
        }

        var diskCoordinates = [DiskCoordinate]()

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine = [DiskCoordinate]()
            flipping: while true {
                x += direction.x
                y += direction.y

                let diskAtCoordinate = boardView.diskAt(DiskCoordinate(x: x, y: y))
                switch (disk, diskAtCoordinate) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append(DiskCoordinate(x: x, y: y))
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
    private func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, at: DiskCoordinate(x: x, y: y)).isEmpty
    }

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    private func validMoves(for side: Disk) -> [DiskCoordinate] {
        var coordinates = [DiskCoordinate]()

        for y in 0..<BoardView.yCount {
            for x in 0..<BoardView.xCount {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append(DiskCoordinate(x: x, y: y))
                }
            }
        }

        return coordinates
    }

    /// `x`, `y` で指定されたセルに `disk` を置きます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter isAnimated: ディスクを置いたりひっくり返したりするアニメーションを表示するかどうかを指定します。
    /// - Parameter completion: アニメーション完了時に実行されるクロージャです。
    ///     このクロージャは値を返さず、アニメーションが完了したかを示す真偽値を受け取ります。
    ///     もし `animated` が `false` の場合、このクロージャは次の run loop サイクルの初めに実行されます。
    /// - Throws: もし `disk` を `x`, `y` で指定されるセルに置けない場合、 `DiskPlacementError` を `throw` します。
    private func placeDisk(_ disk: Disk, at coordinate: DiskCoordinate, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) throws {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, coordinate: coordinate)
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk) { [weak self] isFinished in
                guard let self = self else { return }
                guard let canceller = self.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                completion?(isFinished)
                try? GameIO.saveGame(gameState: GameState(turn: self.turn,
                                                          darkControlIndex: self.darkPlayerControl.selectedSegmentIndex,
                                                          lightControlIndex: self.lightPlayerControl.selectedSegmentIndex,
                                                          boardStates: self.boardView.getBoardStates()))

                self.darkCountLabel.text = "\(self.boardView.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.boardView.countDisks(of: .light))"
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.setDisk(disk, at: coordinate, animated: false)
                for coordinate in diskCoordinates {
                    self.boardView.setDisk(disk, at: coordinate, animated: false)
                }
                completion?(true)
                try? GameIO.saveGame(gameState: GameState(turn: self.turn,
                                                          darkControlIndex: self.darkPlayerControl.selectedSegmentIndex,
                                                          lightControlIndex: self.lightPlayerControl.selectedSegmentIndex,
                                                          boardStates: self.boardView.getBoardStates()))

                self.darkCountLabel.text = "\(self.boardView.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.boardView.countDisks(of: .light))"
            }
        }
    }

    /// `coordinates` で指定されたセルに、アニメーションしながら順番に `disk` を置く。
    /// `coordinates` から先頭の座標を取得してそのセルに `disk` を置き、
    /// 残りの座標についてこのメソッドを再帰呼び出しすることで処理が行われる。
    /// すべてのセルに `disk` が置けたら `completion` ハンドラーが呼び出される。
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == DiskCoordinate
    {
        guard let coordinate = coordinates.first else {
            completion(true)
            return
        }

        let animationCanceller = self.animationCanceller!
        boardView.setDisk(disk, at: coordinate, animated: true) { [weak self] isFinished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if isFinished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for coordinate in coordinates {
                    self.boardView.setDisk(disk, at: coordinate, animated: false)
                }
                completion(false)
            }
        }
    }
}

extension ViewController: BoardViewDelegate {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate) {
        if isAnimating { return }
        let playerControl = (turn == .dark) ? darkPlayerControl : lightPlayerControl
        guard case .human = PlayerType(rawValue: playerControl!.selectedSegmentIndex)! else { return }
        // try? because doing nothing when an error occurs
        try? placeDisk(turn, at: coordinate, animated: true) { [weak self] _ in
            self?.nextTurn()
        }
    }
}
