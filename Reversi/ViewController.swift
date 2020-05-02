import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!

    private var game = Game()
    private var isGameOver = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        boardView.configure(board: game.board)
        
        do {
            try loadGame()
        } catch _ {
            newGame()
        }
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
    /// ゲームの状態を初期化し、新しいゲームを開始します。
    func newGame() {
        boardView.reset()
        game.turn = .dark
        
        for playerControl in playerControls {
            playerControl.selectedSegmentIndex = Player.manual.rawValue
        }

        updateMessageViews(side: .dark)
        updateCountLabels()
        
        try? saveGame()
    }
    
    /// プレイヤーの行動を待ちます。
    func waitForPlayer() {
        let turn = game.turn
        switch Player(rawValue: playerControls[turn.index].selectedSegmentIndex)! {
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
                isGameOver = true
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
        for side in Disk.sides {
            countLabels[side.index].text = "\(game.board.countDisks(of: side))"
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
            
            for side in Disk.sides {
                self.boardView.playerCancellers[side]?.cancel()
                self.boardView.playerCancellers.removeValue(forKey: side)
            }
            
            self.newGame()
            self.waitForPlayer()
        })
        present(alertController, animated: true)
    }
    
    /// プレイヤーのモードが変更された場合に呼ばれるハンドラーです。
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side = Disk(index: playerControls.firstIndex(of: sender)!)
        
        try? saveGame()
        
        if let canceller = boardView.playerCancellers[side] {
            canceller.cancel()
        }
        
        if !boardView.isAnimating, !isGameOver, case .computer = Player(rawValue: sender.selectedSegmentIndex)! {
            playTurnOfComputer()
        }
    }

    private func playTurnOfComputer() {
        let turn = game.turn
        let coordinate = game.board.validMoves(for: turn).randomElement()!
        playerActivityIndicators[turn.index].startAnimating()
        let (diskCoordinates, placeTypes) = try! game.board.placeDisk(turn, at: coordinate)
        boardView.playTurnOfComputer(turn: turn, coordinate: coordinate, diskCoordinates: diskCoordinates, placeTypes: placeTypes) { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[turn.index].stopAnimating()
            self.nextTurn()
            try? self.saveGame()
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
        guard case .manual = Player(rawValue: playerControls[turn.index].selectedSegmentIndex)! else { return }

        guard let (diskCoordinates, placeTypes) = try? game.board.placeDisk(turn, at: coordinate) else { return }
        try? boardView.placeDisk(diskCoordinates: diskCoordinates, placeTypes: placeTypes, disk: turn, at: coordinate, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.nextTurn()
            try? self.saveGame()
            self.updateCountLabels()
        }
    }
}

// MARK: Save and Load

extension ViewController {
    private var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }
    
    /// ゲームの状態をファイルに書き出し、保存します。
    func saveGame() throws {
        var output: String = ""
        let diskForSymbol = isGameOver ? nil : game.turn
        output += Symbol(disk: diskForSymbol).rawValue
        for side in Disk.sides {
            output += playerControls[side.index].selectedSegmentIndex.description
        }
        output += "\n"
        
        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let diskOnCell = boardView.diskAt(Coordinate(x: x, y: y))
                output += Symbol(disk: diskOnCell).rawValue
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
    func loadGame() throws {
        let input = try String(contentsOfFile: path, encoding: .utf8)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]
        
        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }
        
        do { // turn
            guard
                let diskSymbolString = line.popFirst()?.description,
                let disk = Symbol(rawValue: diskSymbolString)?.disk
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            game.turn = disk
        }

        // players
        for side in Disk.sides {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = Player(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            playerControls[side.index].selectedSegmentIndex = player.rawValue
        }

        do { // board
            guard lines.count == Board.height else {
                throw FileIOError.read(path: path, cause: nil)
            }
            
            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Symbol(rawValue: character.description)?.disk
                    let coordinate = Coordinate(x: x, y: y)
                    boardView.setDisk(disk, at: coordinate, animated: false)
                    game.board.lines[y][x] = Squire(disk: disk, coordinate: coordinate)
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

        updateMessageViews(side: game.turn)
        updateCountLabels()
    }
    
    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

// MARK: Additional types

extension ViewController {
    enum Player: Int {
        case manual = 0
        case computer = 1
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
    let coordinate: Coordinate
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
