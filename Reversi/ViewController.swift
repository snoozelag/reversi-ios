import UIKit

class ViewController: UIViewController {

    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var darkPlayerControl: UISegmentedControl!
    @IBOutlet private var lightPlayerControl: UISegmentedControl!
    @IBOutlet private var countLabels: [UILabel]!
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
            let diskState = try GameIO.loadGame()

            turn = diskState.turn
            darkPlayerControl.selectedSegmentIndex = diskState.darkControlIndex
            lightPlayerControl.selectedSegmentIndex = diskState.lightControlIndex
            diskState.boardStates.forEach({
                boardView.setDisk($0.disk, atX: $0.x, y: $0.y, animated: false)
            })
        } catch _ {
            newGame()
        }

        updateMessageViews(side: .dark)
        updateCountLabels()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewHasAppeared {
            viewHasAppeared = true
            waitForPlayer()
        }
    }

    // MARK: - Inputs

    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
    @IBAction private func pressResetButton(_ sender: UIButton) {
        showResetGameDialog()
    }

    @IBAction private func darkPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let player = Player(rawValue: sender.selectedSegmentIndex)!
        changePlayer(side: .dark, player: player)
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let player = Player(rawValue: sender.selectedSegmentIndex)!
        changePlayer(side: .light, player: player)
    }

    // MARK: - Views

    /// 各プレイヤーの獲得したディスクの枚数を表示します。
    private func updateCountLabels() {
        for side in Disk.allCases {
            countLabels[side.index].text = "\(boardView.countDisks(of: side))"
        }
    }

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

    /// 人間、コンピュータを変更
    private func changePlayer(side: Disk, player: Player) {

        try? GameIO.saveGame(diskState: DiskState(turn: turn,
                                                  darkControlIndex: darkPlayerControl.selectedSegmentIndex,
                                                  lightControlIndex: lightPlayerControl.selectedSegmentIndex,
                                                  boardStates: []), boardStateString: boardView.getBoardStatesString())

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

        darkPlayerControl.selectedSegmentIndex = Player.manual.rawValue
        lightPlayerControl.selectedSegmentIndex = Player.manual.rawValue

        try? GameIO.saveGame(diskState: DiskState(turn: turn,
                                                  darkControlIndex: darkPlayerControl.selectedSegmentIndex,
                                                  lightControlIndex: lightPlayerControl.selectedSegmentIndex,
                                                  boardStates: []), boardStateString: boardView.getBoardStatesString())
    }

    /// プレイヤーの行動を待ちます。
    private func waitForPlayer() {
        let playerControl = (turn == .dark) ? darkPlayerControl : lightPlayerControl
        switch Player(rawValue: playerControl!.selectedSegmentIndex)! {
        case .manual:
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
        } else {
            updateMessageViews(side: turn)
            waitForPlayer()
        }
    }

    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    private func playTurnOfComputer() {
        let (x, y) = validMoves(for: turn).randomElement()!

        playerActivityIndicators[turn.index].startAnimating()

        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[self.turn.index].stopAnimating()
            self.playerCancellers[self.turn] = nil
        }
        let canceller = Canceller(cleanUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            try! self.placeDisk(self.turn, atX: x, y: y, animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }

        playerCancellers[turn] = canceller
    }

    // MARK: - Reversi logics

    private func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
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

        guard boardView.diskAt(x: x, y: y) == nil else {
            return []
        }

        var diskCoordinates: [(Int, Int)] = []

        for direction in directions {
            var x = x
            var y = y

            var diskCoordinatesInLine: [(Int, Int)] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                switch (disk, boardView.diskAt(x: x, y: y)) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append((x, y))
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
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }

    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    private func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        var coordinates: [(Int, Int)] = []

        for y in BoardView.yRange {
            for x in BoardView.xRange {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append((x, y))
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
    private func placeDisk(_ disk: Disk, atX x: Int, y: Int, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) throws {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: x, y: y)
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [(x, y)] + diskCoordinates, to: disk) { [weak self] isFinished in
                guard let self = self else { return }
                guard let canceller = self.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                completion?(isFinished)
                try? GameIO.saveGame(diskState: DiskState(turn: self.turn,
                                                          darkControlIndex: self.darkPlayerControl.selectedSegmentIndex,
                                                          lightControlIndex: self.lightPlayerControl.selectedSegmentIndex,
                                                          boardStates: []), boardStateString: self.boardView.getBoardStatesString())
                self.updateCountLabels()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.setDisk(disk, atX: x, y: y, animated: false)
                for (x, y) in diskCoordinates {
                    self.boardView.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion?(true)
                try? GameIO.saveGame(diskState: DiskState(turn: self.turn,
                                                          darkControlIndex: self.darkPlayerControl.selectedSegmentIndex,
                                                          lightControlIndex: self.lightPlayerControl.selectedSegmentIndex,
                                                          boardStates: []), boardStateString: self.boardView.getBoardStatesString())
                self.updateCountLabels()
            }
        }
    }

    /// `coordinates` で指定されたセルに、アニメーションしながら順番に `disk` を置く。
    /// `coordinates` から先頭の座標を取得してそのセルに `disk` を置き、
    /// 残りの座標についてこのメソッドを再帰呼び出しすることで処理が行われる。
    /// すべてのセルに `disk` が置けたら `completion` ハンドラーが呼び出される。
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == (Int, Int)
    {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }

        let animationCanceller = self.animationCanceller!
        boardView.setDisk(disk, atX: x, y: y, animated: true) { [weak self] isFinished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if isFinished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.boardView.setDisk(disk, atX: x, y: y, animated: false)
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
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        if isAnimating { return }
        let playerControl = (turn == .dark) ? darkPlayerControl : lightPlayerControl
        guard case .manual = Player(rawValue: playerControl!.selectedSegmentIndex)! else { return }
        // try? because doing nothing when an error occurs
        try? placeDisk(turn, atX: x, y: y, animated: true) { [weak self] _ in
            self?.nextTurn()
        }
    }
}
