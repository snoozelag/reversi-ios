import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var boardView: BoardView!
    @IBOutlet private weak var messageDiskView: DiskView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var darkPlayerControl: UISegmentedControl!
    @IBOutlet private weak var lightPlayerControl: UISegmentedControl!
    @IBOutlet private weak var darkCountLabel: UILabel!
    @IBOutlet private weak var lightCountLabel: UILabel!
    @IBOutlet private weak var darkPlayerActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var lightPlayerActivityIndicator: UIActivityIndicatorView!

    private var game = Game()
    private var isFlipAnimating: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        
        do {
            try game.load()
        } catch _ {
            self.game = Game()
            try? game.save()
        }

        boardView.configure(board: game.board)
        updateSegmentedControls()
        updateMessageViews()
        updateCountLabels()
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        playIfTurnOfComputer(side: game.turn)
    }

    private func playerActivityIndicator(side: Disk) -> UIActivityIndicatorView {
        let indicators = [Disk.dark: darkPlayerActivityIndicator!, Disk.light: lightPlayerActivityIndicator!]
        return indicators[side]!
    }

    // MARK: - Alert

    private func showResetDialog(okHandler: @escaping () -> Void) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            okHandler()
        }))
        present(alertController, animated: true)
    }

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
}

// MARK: Game management

extension ViewController {

    private func nextTurn() {
        switch game.flipTurn() {
        case .change:
            playIfTurnOfComputer(side: game.turn)
        case .pass:
            showPassDialog(dismissHandler: { [weak self] in
                self?.nextTurn()
            })
        case .gameOver:
            break
        }
        updateMessageViews()
    }

    private func getComputerTurnCoordinates(turn: Disk, completion: @escaping ([Coordinate]) -> Void) {
        let coordinate = game.board.validMoves(for: game.turn).randomElement()!
        let playerActivityIndicator = self.playerActivityIndicator(side: turn)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            guard playerActivityIndicator.isAnimating else { return }
            let disk = turn
            let diskCoordinates = self.game.board.flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)!
            completion([coordinate] + diskCoordinates)
        }
    }
    
    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    private func playIfTurnOfComputer(side: Disk) {
        guard !game.isOver else { return }
        guard side == game.turn, game.player(disk: side) == .computer else { return }

        let playerActivityIndicator = self.playerActivityIndicator(side: side)
        playerActivityIndicator.startAnimating()
        getComputerTurnCoordinates(turn: side, completion: { [weak self] coordinates in
            playerActivityIndicator.stopAnimating()
            self?.flip(disk: side, coordinates: coordinates, completion: {
                self?.nextTurn()
            })
        })
    }

    private func flip(disk: Disk, coordinates: [Coordinate], completion: (() -> Void)?) {
        let squires = coordinates.map { game.board.lines[$0.y][$0.x] }

        self.isFlipAnimating = true
        boardView.setDisks(after: disk, at: squires, animated: true, flippedHandler: nil, completion: { [weak self] in
                guard let self = self else { return }
                guard self.isFlipAnimating else { return }
                self.isFlipAnimating = false

                self.game.board.setDisks(disk, at: coordinates)
                try? self.game.save()
                self.updateCountLabels()

                completion?()
        })
    }
}

// MARK: Views

extension ViewController {
    /// 各プレイヤーの獲得したディスクの枚数を表示します。
    private func updateCountLabels() {
        darkCountLabel.text = "\(game.board.countDisks(of: .dark))"
        lightCountLabel.text = "\(game.board.countDisks(of: .light))"
    }

    private func updateSegmentedControls() {
        darkPlayerControl.selectedSegmentIndex = game.darkPlayer.rawValue
        lightPlayerControl.selectedSegmentIndex = game.lightPlayer.rawValue
    }
    
    /// 現在の状況に応じてメッセージを表示します。
    private func updateMessageViews() {
        if game.isOver {
            if let winner = game.board.sideWithMoreDisks() {
                messageDiskView.isHidden = false
                messageDiskView.configure(disk: winner)
                messageLabel.text = " won"
            } else {
                messageDiskView.isHidden = true
                messageLabel.text = "Tied"
            }
        } else {
            messageDiskView.isHidden = false
            messageDiskView.configure(disk: game.turn)
            messageLabel.text = "'s turn"
        }
    }
}

// MARK: Inputs

extension ViewController {

    @IBAction private func pressResetButton(_ sender: UIButton) {
        showResetDialog(okHandler: { [weak self] in
            guard let self = self else { return }

            self.isFlipAnimating = false
            self.darkPlayerActivityIndicator.stopAnimating()
            self.lightPlayerActivityIndicator.stopAnimating()

            self.game = Game()
            try? self.game.save()
            self.boardView.configure(board: self.game.board)
            self.updateSegmentedControls()
            self.updateMessageViews()
            self.updateCountLabels()
            self.playIfTurnOfComputer(side: self.game.turn)
        })
    }

    @IBAction private func darkPlayerControlValueChanged(_ sender: UISegmentedControl) {
        game.darkPlayer = Player(rawValue: sender.selectedSegmentIndex)!
        try? game.save()

        if darkPlayerActivityIndicator.isAnimating {
            darkPlayerActivityIndicator.stopAnimating()
        }
        if !isFlipAnimating, !game.isOver {
            playIfTurnOfComputer(side: .dark)
        }
    }

    @IBAction private func lightPlayerControlValueChanged(_ sender: UISegmentedControl) {
        game.lightPlayer = Player(rawValue: sender.selectedSegmentIndex)!
        try? game.save()

        if lightPlayerActivityIndicator.isAnimating {
            lightPlayerActivityIndicator.stopAnimating()
        }
        if !isFlipAnimating, !game.isOver {
            playIfTurnOfComputer(side: .light)
        }
    }
}

extension ViewController: BoardViewDelegate {

    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate) {
        guard !game.isOver, !isFlipAnimating, game.player(disk: game.turn) == .manual else { return }
        guard let diskCoordinates = game.board.flippedDiskCoordinatesByPlacingDisk(game.turn, at: coordinate) else { return }
        flip(disk: game.turn, coordinates: [coordinate] + diskCoordinates) { [weak self] in
            self?.nextTurn()
        }
    }
}
