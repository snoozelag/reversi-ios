import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!

    private var game = Game()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        
        do {
            try game.load()
        } catch _ {
            game.new()
        }

        boardView.configure(board: game.board)
        updateMessageViews(side: game.turn)
        updateCountLabels()
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        waitForPlayer()
    }
}

// MARK: Game management

extension ViewController {
    
    /// プレイヤーの行動を待ちます。
    func waitForPlayer() {
        switch game.turnPlayerType {
        case .manual:
            break
        case .computer:
            playTurnOfComputer()
        }
    }
    
    /// プレイヤーの行動後、そのプレイヤーのターンを終了して次のターンを開始します。
    /// もし、次のプレイヤーに有効な手が存在しない場合、パスとなります。
    /// 両プレイヤーに有効な手がない場合、ゲームの勝敗を表示します。
    func nextTurn() {

        let flippedTurn = game.turn.flipped
        
        if game.board.validMoves(for: flippedTurn).isEmpty {
            if game.board.validMoves(for: flippedTurn.flipped).isEmpty {
                game.isOver = true
                updateMessageViewsGameOver()
            } else {
                game.turn = flippedTurn
                updateMessageViews(side: flippedTurn)
                
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
            game.turn = flippedTurn
            updateMessageViews(side: flippedTurn)
            waitForPlayer()
        }
    }
}

// MARK: Views

extension ViewController {
    /// 各プレイヤーの獲得したディスクの枚数を表示します。
    func updateCountLabels() {
        for side in Disk.allCases {
            countLabels[side.viewIndex].text = "\(game.board.countDisks(of: side))"
        }
    }

    func updateMessageViews(side: Disk) {
        messageDiskView.isHidden = false
        messageDiskView.disk = side
        messageLabel.text = "'s turn"
    }

    func updateMessageViewsGameOver() {
        if let winner = game.board.sideWithMoreDisks() {
            messageDiskView.isHidden = false
            messageDiskView.disk = winner
            messageLabel.text = " won"
        } else {
            messageDiskView.isHidden = true
            messageLabel.text = "Tied"
        }
    }
}

// MARK: Inputs

extension ViewController {
    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
    @IBAction func pressResetButton(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            self.boardView.animationCanceller?.cancel()
            self.boardView.animationCanceller = nil
            
            for side in Disk.allCases {
                self.boardView.playerCancellers[side]?.cancel()
                self.boardView.playerCancellers.removeValue(forKey: side)
            }
            
            self.game.new()
            self.waitForPlayer()
        })
        present(alertController, animated: true)
    }

    @IBAction private func darkPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        segmentedControlValueChangedAction(side: .dark, playerType: PlayerType(rawValue: sender.selectedSegmentIndex)!)
    }

    @IBAction private func lightPlayerSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        segmentedControlValueChangedAction(side: .light, playerType: PlayerType(rawValue: sender.selectedSegmentIndex)!)
    }

    private func segmentedControlValueChangedAction(side: Disk, playerType: PlayerType) {
        try? game.save()
        if let canceller = boardView.playerCancellers[side] {
            canceller.cancel()
        }
        if !boardView.isAnimating, !game.isOver, case .computer = playerType {
            playTurnOfComputer()
        }
    }

    private func playTurnOfComputer() {
        let turn = game.turn
        let coordinate = game.board.validMoves(for: turn).randomElement()!
        playerActivityIndicators[turn.viewIndex].startAnimating()
        let (diskCoordinates, placeTypes) = try! game.board.placeDisk(turn, at: coordinate)
        boardView.playTurnOfComputer(turn: turn, coordinate: coordinate, diskCoordinates: diskCoordinates, placeTypes: placeTypes) { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[turn.viewIndex].stopAnimating()
            self.nextTurn()
            try? self.game.save()
            self.updateCountLabels()
        }
    }
}

extension ViewController: BoardViewDelegate {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate) {
        let turn = game.turn
        if boardView.isAnimating { return }
        guard case .manual = PlayerType(rawValue: playerControls[turn.viewIndex].selectedSegmentIndex)! else { return }

        guard let (diskCoordinates, placeTypes) = try? game.board.placeDisk(turn, at: coordinate) else { return }
        try? boardView.placeDisk(diskCoordinates: diskCoordinates, placeTypes: placeTypes, disk: turn, at: coordinate, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.nextTurn()
            try? self.game.save()
            self.updateCountLabels()
        }
    }
}
