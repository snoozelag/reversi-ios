import UIKit

class ViewController: UIViewController {

    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!

    private var game = Game()
    
    private var animationCanceller: Canceller?
    private var isAnimating: Bool { animationCanceller != nil }
    private var playerCancellers: [Disk: Canceller] = [:]
    
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
        playIfTurnOfComputer(playerIndex: game.turn.index)
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

    func nextTurn() {
        switch game.flipTurn() {
        case .change:
            playIfTurnOfComputer(playerIndex: game.turn.index)
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
        playerActivityIndicators[game.turn.index].startAnimating()
        let coordinate = game.board.validMoves(for: game.turn).randomElement()!
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerCancellers[turn] = nil
            self.playerActivityIndicators[turn.index].stopAnimating()
        }
        let canceller = Canceller(cleanUp)
        playerCancellers[turn] = canceller
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()
            let disk = turn
            let diskCoordinates = self.game.board.flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)!
            completion([coordinate] + diskCoordinates)
        }
    }
    
    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    func playIfTurnOfComputer(playerIndex: Int) {
        let turn = game.turn
        guard turn.index == playerIndex, case .computer = game.players[playerIndex] else { return }
        guard !game.isOver else { preconditionFailure() }

        getComputerTurnCoordinates(turn: turn, completion: { [weak self] coordinates in
            self?.flip(disk: turn, coordinates: coordinates, completion: {
                self?.nextTurn()
            })
        })
    }

    private func flip(disk: Disk, coordinates: [Coordinate], completion: (() -> Void)?) {
        let cleanUp: () -> Void = { [weak self] in
            self?.animationCanceller = nil
        }
        self.animationCanceller = Canceller(cleanUp)
        let squires = coordinates.map { game.board.lines[$0.y][$0.x] }
        let animationCanceller = self.animationCanceller!

        boardView.setDisks(after: disk, at: squires, animated: false, flippedHandler: nil, completion: { [weak self] in
                guard let self = self else { return }
                if animationCanceller.isCancelled { return }
                cleanUp()

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
    func updateCountLabels() {
        for side in Disk.sides {
            countLabels[side.index].text = "\(game.board.countDisks(of: side))"
        }
    }

    func updateSegmentedControls() {
        for (index, playerControl) in game.players.enumerated() {
            playerControls[index].selectedSegmentIndex = playerControl.rawValue
        }
    }
    
    /// 現在の状況に応じてメッセージを表示します。
    func updateMessageViews() {
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

    @IBAction func pressResetButton(_ sender: UIButton) {
        showResetDialog(okHandler: { [weak self] in
            guard let self = self else { return }

            self.animationCanceller?.cancel()
            self.animationCanceller = nil

            for side in Disk.sides {
                self.playerCancellers[side]?.cancel()
                self.playerCancellers.removeValue(forKey: side)
            }

            self.game = Game()
            try? self.game.save()
            self.boardView.configure(board: self.game.board)
            self.updateSegmentedControls()
            self.updateMessageViews()
            self.updateCountLabels()
            self.playIfTurnOfComputer(playerIndex: self.game.turn.index)
        })
    }

    /// プレイヤーのモードが変更された場合に呼ばれるハンドラーです。
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side = Disk(index: playerControls.firstIndex(of: sender)!)
        game.players[side.index] = Player(rawValue: sender.selectedSegmentIndex)!

        try? game.save()

        if let canceller = playerCancellers[side] {
            canceller.cancel()
        }

        if !isAnimating, !game.isOver {
            playIfTurnOfComputer(playerIndex: side.index)
        }
    }
}

extension ViewController: BoardViewDelegate {

    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate) {
        let disk = game.turn
        guard !game.isOver, !isAnimating, case .manual = game.players[disk.index] else { return }
        guard let diskCoordinates = game.board.flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate) else { return }
        flip(disk: disk, coordinates: [coordinate] + diskCoordinates) { [weak self] in
            self?.nextTurn()
        }
    }
}

final class Canceller {
    private(set) var isCancelled: Bool = false
    private let body: (() -> Void)?
    
    init(_ body: (() -> Void)?) {
        self.body = body
    }
    
    func cancel() {
        if isCancelled { return }
        isCancelled = true
        body?()
    }
}

// MARK: File-private extensions

extension Disk {
    init(index: Int) {
        for side in Disk.sides {
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
