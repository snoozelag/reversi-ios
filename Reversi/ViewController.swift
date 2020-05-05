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
            let board = try game.load()
            boardView.board = board
            boardView.configureBoard()
        } catch _ {
            self.game = Game()
            try? game.save(board: boardView.board)
        }

        updateSegmentedControls()
        updateMessageViews()
        updateCountLabels()
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        waitForPlayer()
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

// MARK: Reversi logics

extension ViewController {
    
    /// `coordinates` で指定されたセルに、アニメーションしながら順番に `disk` を置く。
    /// `coordinates` から先頭の座標を取得してそのセルに `disk` を置き、
    /// 残りの座標についてこのメソッドを再帰呼び出しすることで処理が行われる。
    /// すべてのセルに `disk` が置けたら `completion` ハンドラーが呼び出される。
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping () -> Void)
        where C.Element == Coordinate
    {
        guard let coordinate = coordinates.first else {
            completion()
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
                completion()
            }
        }
    }
}

// MARK: Game management

extension ViewController {

    /// プレイヤーの行動を待ちます。
    func waitForPlayer() {
        guard !game.isOver else { return }
        playIfTurnOfComputer(playerIndex: game.turn.index)
    }
    
    /// プレイヤーの行動後、そのプレイヤーのターンを終了して次のターンを開始します。
    /// もし、次のプレイヤーに有効な手が存在しない場合、パスとなります。
    /// 両プレイヤーに有効な手がない場合、ゲームの勝敗を表示します。
    func nextTurn() {
        guard !game.isOver else { return }

        game.turn.flip()
        
        if boardView.board.validMoves(for: game.turn).isEmpty {
            if boardView.board.validMoves(for: game.turn.flipped).isEmpty {
                game.isOver = true
                updateMessageViews()
            } else {
                updateMessageViews()
                showPassDialog(dismissHandler: { [weak self] in
                    self?.nextTurn()
                })
            }
        } else {
            updateMessageViews()
            waitForPlayer()
        }
    }
    
    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    func playIfTurnOfComputer(playerIndex: Int) {
        let turn = game.turn
        guard turn.index == playerIndex, case .computer = game.players[playerIndex] else { return }
        guard !game.isOver else { preconditionFailure() }
        let coordinate = boardView.board.validMoves(for: game.turn).randomElement()!

        playerActivityIndicators[game.turn.index].startAnimating()
        
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[turn.index].stopAnimating()
            self.playerCancellers[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            let disk = turn
            let placeCompletion: (() -> Void)? = { [weak self] in
                self?.nextTurn()
            }

            let diskCoordinates = self.boardView.board.flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
            guard !diskCoordinates.isEmpty else {
//                throw DiskPlacementError(disk: disk, x: x, y: y)
                return
            }

            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            self.animationCanceller = Canceller(cleanUp)
            self.animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk) { [weak self] in
                guard let self = self else { return }
                guard let canceller = self.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                placeCompletion?()
                try? self.game.save(board: self.boardView.board)
                self.updateCountLabels()
            }
        }
        
        playerCancellers[game.turn] = canceller
    }
}

// MARK: Views

extension ViewController {
    /// 各プレイヤーの獲得したディスクの枚数を表示します。
    func updateCountLabels() {
        for side in Disk.sides {
            countLabels[side.index].text = "\(boardView.board.countDisks(of: side))"
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
            if let winner = boardView.board.sideWithMoreDisks() {
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
    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
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
            try? self.game.save(board: self.boardView.board)
            self.updateSegmentedControls()
            self.updateMessageViews()
            self.updateCountLabels()

            self.waitForPlayer()
        })
    }
    
    /// プレイヤーのモードが変更された場合に呼ばれるハンドラーです。
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)

        game.players[side.index] = Player(rawValue: sender.selectedSegmentIndex)!
        try? game.save(board: boardView.board)
        
        if let canceller = playerCancellers[side] {
            canceller.cancel()
        }
        
        if !isAnimating, !game.isOver {
            playIfTurnOfComputer(playerIndex: side.index)
        }
    }
}

extension ViewController: BoardViewDelegate {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate) {
        guard !game.isOver else { return }
        if isAnimating { return }
        guard case .manual = Player(rawValue: playerControls[game.turn.index].selectedSegmentIndex)! else { return }
        // try? because doing nothing when an error occurs
        let disk = game.turn
        let placeCompletion: (() -> Void)? = { [weak self] in
            self?.nextTurn()
        }

        let diskCoordinates = boardView.board.flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
        guard !diskCoordinates.isEmpty else {
            //                throw DiskPlacementError(disk: disk, x: x, y: y)
            return
        }

        let cleanUp: () -> Void = { [weak self] in
            self?.animationCanceller = nil
        }
        self.animationCanceller = Canceller(cleanUp)
        self.animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk) { [weak self] in
            guard let self = self else { return }
            guard let canceller = self.animationCanceller else { return }
            if canceller.isCancelled { return }
            cleanUp()

            placeCompletion?()
            try? self.game.save(board: boardView.board)
            self.updateCountLabels()
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

struct DiskPlacementError: Error {
    let disk: Disk
    let x: Int
    let y: Int
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

enum Symbol: String {
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

public struct Coordinate {
    var x: Int
    var y: Int
}

