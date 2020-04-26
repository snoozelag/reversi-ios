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

    /// どちらの色のプレイヤーのターンかを表します。ゲーム終了時は `nil` です。
    private var animationCanceller: Canceller?
    private var isAnimating: Bool { animationCanceller != nil }
    private var darkCanceller: Canceller?
    private var lightCanceller: Canceller?
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

        darkCanceller?.cancel()
        lightCanceller?.cancel()

        if !isAnimating, case .computer = playerType, gameState.turn == .dark {
            playTurnOfComputer(turn: .dark) {

            }
        }
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let playerType = PlayerType(rawValue: sender.selectedSegmentIndex)!
        gameState.lightPlayerType = playerType
        try? GameStore.saveGame(gameState: gameState)

        darkCanceller?.cancel()
        lightCanceller?.cancel()

        if !isAnimating, case .computer = playerType, gameState.turn == .light {
            playTurnOfComputer(turn: .light) {

            }
        }
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

    /// ゲームのリセット
    private func resetGame() {
        animationCanceller?.cancel()
        animationCanceller = nil
        darkCanceller?.cancel()
        darkCanceller = nil
        lightCanceller?.cancel()
        lightCanceller = nil

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
                self.darkCanceller = nil
            case .light:
                self.lightCanceller = nil
            }
        }
        let canceller = Canceller(cleanUp)
        switch turn {
        case .dark:
            darkCanceller = canceller
        case .light:
            lightCanceller = canceller
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            canceller.cancel()
            try? self.placeDisk(squire: SquireState(disk: turn, coordinate: coordinate), animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }
    }

    // MARK: - Reversi logics

    private func flippedDiskCoordinatesByPlacingDisk(placing: SquireState) -> [DiskCoordinate] {

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

    /// `x`, `y` で指定されたセルに、 `disk` が置けるかを調べます。
    /// ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要があります。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: 指定されたセルに `disk` を置ける場合は `true` を、置けない場合は `false` を返します。
    private func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(placing: SquireState(disk: disk, coordinate: DiskCoordinate(x: x, y: y))).isEmpty
    }

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    private func validMoves(for side: Disk) -> [DiskCoordinate] {
        var coordinates = [DiskCoordinate]()

        for y in 0..<Board.yCount {
            for x in 0..<Board.xCount {
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
    private func placeDisk(squire: SquireState, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) throws {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(placing: squire)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: squire.disk!, coordinate: squire.coordinate)
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [squire.coordinate] + diskCoordinates, to: squire.disk!) { [weak self] isFinished in
                guard let self = self else { return }
                guard let canceller = self.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                completion?(isFinished)
                try? GameStore.saveGame(gameState: self.gameState)

                self.darkCountLabel.text = "\(self.gameState.board.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.gameState.board.countDisks(of: .light))"
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.setDisk(squire: squire, animated: false)
                for coordinate in diskCoordinates {
                    self.boardView.setDisk(squire: SquireState(disk: squire.disk, coordinate: coordinate), animated: false)
                }
                completion?(true)
                try? GameStore.saveGame(gameState: self.gameState)

                self.darkCountLabel.text = "\(self.gameState.board.countDisks(of: .dark))"
                self.lightCountLabel.text = "\(self.gameState.board.countDisks(of: .light))"
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

        let squire = SquireState(disk: disk, coordinate: coordinate)
        gameState.board.setDisk(squire: squire)
        boardView.setDisk(squire: squire, animated: true) { [weak self] isFinished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if isFinished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for coordinate in coordinates {
                    self.boardView.setDisk(squire: SquireState(disk: disk, coordinate: coordinate), animated: false)
                }
                completion(false)
            }
        }
    }
}

extension ViewController: BoardViewDelegate {
    
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate) {
        if isAnimating { return }
        let playerControl = (gameState.turn == .dark) ? darkPlayerControl : lightPlayerControl
        guard case .human = PlayerType(rawValue: playerControl!.selectedSegmentIndex)! else { return }
        // try? because doing nothing when an error occurs
        try? placeDisk(squire: SquireState(disk: gameState.turn, coordinate: coordinate), animated: true) { [weak self] _ in
            self?.nextTurn()
        }
    }
}
