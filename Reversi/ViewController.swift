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

            if case .computer = gameState.turnPlayer {
                playOnComputer()
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

        if case .computer = playerType, gameState.turn == .dark {
            playOnComputer()
        }
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let playerType = PlayerType(rawValue: sender.selectedSegmentIndex)!
        gameState.lightPlayerType = playerType
        try? GameStore.saveGame(gameState: gameState)

        if case .computer = playerType, gameState.turn == .light {
            playOnComputer()
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
    private func showPassDialog(dismissHandler: @escaping () -> Void) {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in
            dismissHandler()
        })
        present(alertController, animated: true)
    }


    private func playOnComputer() {
        if let validCoordinates = gameState.board.validMoveCoordinates(for: gameState.turn) {
            inquireComputer(validCoordinates: validCoordinates, turn: gameState.turn, completion: { [weak self] disk, coordinate in
                self?.placeDisk(disk, coordinate: coordinate)
            })
        }
    }

    /// ゲームのリセット
    private func resetGame() {
        gameState = GameState()
        configureViews(gameState: gameState)
        try? GameStore.saveGame(gameState: gameState)
    }

    // MARK: Game management

    /// プレイヤーの行動後、そのプレイヤーのターンを終了して次のターンを開始します。
    /// もし、次のプレイヤーに有効な手が存在しない場合、パスとなります。
    /// 両プレイヤーに有効な手がない場合、ゲームの勝敗を表示します。
    private func changeTurn() {
        gameState.turn.flip()
        let turn = gameState.turn
        switch gameState.board.hasNextTurn(turn) {
        case .valid:
            updateMessageViews(side: turn)
            if gameState.turnPlayer == .computer {
                playOnComputer()
            }
        case .pass:
            changeTurn()
        case .end:
            updateMessageViewsForGameEnd()
        }
    }

    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    private func inquireComputer(validCoordinates: [DiskCoordinate], turn: Disk, completion: @escaping (Disk, DiskCoordinate) -> Void) {
        playerActivityIndicators[turn.rawValue].startAnimating()
        guard let randomCoordinate = validCoordinates.randomElement() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.playerActivityIndicators[turn.rawValue].stopAnimating()
            completion(turn, randomCoordinate)
        }
    }

    // MARK: - Reversi logics

    private func placeDisk(_ disk: Disk, coordinate: DiskCoordinate) {
        let placing = SquireState(disk: disk, coordinate: coordinate)
        let flippedDiskCoordinates = gameState.board.flippedDiskCoordinates(by: placing)
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
            self.changeTurn()
        }
    }
}

extension ViewController: BoardViewDelegate {
    
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate) {
        guard !boardView.isAnimating, case .human = gameState.turnPlayer else { return }
        placeDisk(gameState.turn, coordinate: coordinate)
    }
}
