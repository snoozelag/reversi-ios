import UIKit

class ViewController: UIViewController {

    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var darkPlayerControl: UISegmentedControl!
    @IBOutlet private var lightPlayerControl: UISegmentedControl!
    @IBOutlet private var darkCountLabel: UILabel!
    @IBOutlet private var lightCountLabel: UILabel!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!

    private var viewHasAppeared: Bool = false
    private var gameState = GameState()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        
        do {
            gameState = try GameStore.loadGame()
            configureViews(gameState: gameState)
        } catch _ {
            gameState = GameState()
            configureViews(gameState: gameState)
            try? GameStore.saveGame(gameState: gameState)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewHasAppeared {
            viewHasAppeared = true

            if gameState.turnPlayer == .computer {
                playTurnOfComputer(turn: gameState.turn) {

                }
            }
        }
    }

    private func configureViews(gameState: GameState) {
        boardView.setUp(lines: gameState.board.lines)
        darkPlayerControl.selectedSegmentIndex = gameState.darkPlayerType.rawValue
        lightPlayerControl.selectedSegmentIndex = gameState.lightPlayerType.rawValue

        updateMessageViews(side: gameState.turn)
        darkCountLabel.text = String(gameState.board.countDisks(of: .dark))
        lightCountLabel.text = String(gameState.board.countDisks(of: .light))
    }

    // MARK: - Button Action

    @IBAction private func pressResetButton(_ sender: UIButton) {
        showResetGameDialog()
    }

    @IBAction private func darkPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let playerType = PlayerType(rawValue: sender.selectedSegmentIndex)!
        gameState.darkPlayerType = playerType
        try? GameStore.saveGame(gameState: gameState)

        boardView.darkCanceller?.cancel()
        boardView.lightCanceller?.cancel()

        if !boardView.isAnimating, case .computer = playerType, gameState.turn == .dark {
            playTurnOfComputer(turn: .dark) {

            }
        }
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let playerType = PlayerType(rawValue: sender.selectedSegmentIndex)!
        gameState.lightPlayerType = playerType
        try? GameStore.saveGame(gameState: gameState)

        boardView.darkCanceller?.cancel()
        boardView.lightCanceller?.cancel()

        if !boardView.isAnimating, case .computer = playerType, gameState.turn == .light {
            playTurnOfComputer(turn: .light) {

            }
        }
    }

    // MARK: - Views

    /// 現在のターンをメッセージラベルに表示
    private func updateMessageViews(side: Disk) {
        messageDiskView.isHidden = false
        messageDiskView.configure(disk: side)
        messageLabel.text = "'s turn"
    }

    /// ゲームの結果をメッセージラベルに表示
    private func updateMessageViewsForGameEnd() {
        let darkCount = gameState.board.countDisks(of: .dark)
        let lightCount = gameState.board.countDisks(of: .light)
        if darkCount == lightCount {
            // 引き分けを表示
            messageDiskView.isHidden = true
            messageLabel.text = "Tied"
        } else {
            // 勝者を表示
            let winner: Disk = (darkCount > lightCount) ? .dark : .light
            messageDiskView.isHidden = false
            messageDiskView.configure(disk: winner)
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

    /// ゲームのリセット
    private func resetGame() {
        boardView.cancelAnimations()
        gameState = GameState()
        configureViews(gameState: gameState)
        try? GameStore.saveGame(gameState: gameState)
    }

    // MARK: Game management

    /// プレイヤーの行動後、そのプレイヤーのターンを終了して次のターンを開始します。
    /// もし、次のプレイヤーに有効な手が存在しない場合、パスとなります。
    /// 両プレイヤーに有効な手がない場合、ゲームの勝敗を表示します。
    private func nextTurn() {

        gameState.turn.flip()

        if validMoves(for: gameState.turn).isEmpty {
            if validMoves(for: gameState.turn.flipped).isEmpty {
                updateMessageViewsForGameEnd()
            } else {
                updateMessageViews(side: gameState.turn)
                showPassDialog()
            }
        } else {
            updateMessageViews(side: gameState.turn)

            if gameState.turnPlayer == .computer {
                playTurnOfComputer(turn: gameState.turn) {

                }
            }
        }
    }

    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    private func playTurnOfComputer(turn: Disk, completion: () -> Void) {
        guard let coordinate = validMoves(for: turn).randomElement() else { return }

        playerActivityIndicators[turn.rawValue].startAnimating()

        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[turn.rawValue].stopAnimating()
            switch turn {
            case .dark:
                self.boardView.darkCanceller = nil
            case .light:
                self.boardView.lightCanceller = nil
            }
        }
        let canceller = Canceller(cleanUp)
        switch turn {
        case .dark:
            boardView.darkCanceller = canceller
        case .light:
            boardView.lightCanceller = canceller
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            canceller.cancel()

            let placing = SquireState(disk: turn, coordinate: coordinate)
            let flippedDiskCoordinates = self.flippedDiskCoordinates(by: placing)
            guard !flippedDiskCoordinates.isEmpty else {
                return
            }

            let coordinates = [placing.coordinate] + flippedDiskCoordinates
            self.gameState.board.setDisks(coordinates: coordinates, to: placing.disk!)
            try? GameStore.saveGame(gameState: self.gameState)

            self.boardView.animateSettingDisks(at: coordinates, to: placing.disk!) { [weak self] in
                guard let self = self else { return }
                self.darkCountLabel.text = "\(self.gameState.board.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.gameState.board.countDisks(of: .light))"
                self.nextTurn()
            }
        }
    }

    // MARK: - Reversi logics

    private func flippedDiskCoordinates(by placing: SquireState) -> [DiskCoordinate] {

        let isNotPresent = (gameState.board.squireAt(placing.coordinate)!.disk == nil)
        guard isNotPresent else {
            return []
        }

        var diskCoordinates = [DiskCoordinate]()

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

        for direction in directions {
            var x = placing.coordinate.x
            var y = placing.coordinate.y

            var diskCoordinatesInLine = [DiskCoordinate]()
            flipping: while true {
                x += direction.x
                y += direction.y

                if let directionDisk = gameState.board.squireAt(DiskCoordinate(x: x, y: y))?.disk {
                    switch (placing.disk!, directionDisk) { // Uses tuples to make patterns exhaustive
                    case (.dark, .dark), (.light, .light):
                        diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                        break flipping
                    case (.dark, .light), (.light, .dark):
                        diskCoordinatesInLine.append(DiskCoordinate(x: x, y: y))
                    }
                } else {
                    break
                }

            }
        }

        return diskCoordinates
    }

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    private func validMoves(for side: Disk) -> [DiskCoordinate] {
        var coordinates = [DiskCoordinate]()
        for line in gameState.board.lines {
            for squire in line {
                let placing = SquireState(disk: side, coordinate: squire.coordinate)
                // ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要がある
                let canPlaceDisk = !flippedDiskCoordinates(by: placing).isEmpty
                if canPlaceDisk {
                    coordinates.append(squire.coordinate)
                }
            }
        }
        return coordinates
    }
}

extension ViewController: BoardViewDelegate {
    
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate) {
        if boardView.isAnimating { return }

        if case .computer = gameState.turnPlayer {
            let placing = SquireState(disk: gameState.turn, coordinate: coordinate)
            let flippedDiskCoordinates = self.flippedDiskCoordinates(by: placing)
            guard !flippedDiskCoordinates.isEmpty else {
                return
            }

            let coordinates = [placing.coordinate] + flippedDiskCoordinates
            gameState.board.setDisks(coordinates: coordinates, to: placing.disk!)
            try? GameStore.saveGame(gameState: self.gameState)

            boardView.animateSettingDisks(at: coordinates, to: placing.disk!) { [weak self] in
                guard let self = self else { return }
                self.darkCountLabel.text = "\(self.gameState.board.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.gameState.board.countDisks(of: .light))"
                self.nextTurn()
            }
        }
    }
}
