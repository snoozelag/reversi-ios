import UIKit

private let lineWidth: CGFloat = 2

public class BoardView: UIView {
    private var cellViews: [CellView] = []
    private var actions: [CellSelectionAction] = []

    var animationCanceller: Canceller?
    var isAnimating: Bool { animationCanceller != nil }
    var playerCancellers: [Disk: Canceller] = [:]

    /// セルがタップされたときの挙動を移譲するためのオブジェクトです。
    public weak var delegate: BoardViewDelegate?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func configure(board: Board) {
        self.backgroundColor = UIColor(named: "DarkColor")!
        
        let cellViews = board.lines.reduce(into: [CellView]()) { result, line in
            line.forEach { _ in
                let cellView = CellView()
                cellView.translatesAutoresizingMaskIntoConstraints = false
                result.append(cellView)
            }
        }
        self.cellViews = cellViews
        
        cellViews.forEach(self.addSubview(_:))
        for i in cellViews.indices.dropFirst() {
            NSLayoutConstraint.activate([
                cellViews[0].widthAnchor.constraint(equalTo: cellViews[i].widthAnchor),
                cellViews[0].heightAnchor.constraint(equalTo: cellViews[i].heightAnchor),
            ])
        }
        
        NSLayoutConstraint.activate([
            cellViews[0].widthAnchor.constraint(equalTo: cellViews[0].heightAnchor),
        ])
        
        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let topNeighborAnchor: NSLayoutYAxisAnchor
                if let cellView = cellViewAt(Coordinate(x: x, y: y - 1)) {
                    topNeighborAnchor = cellView.bottomAnchor
                } else {
                    topNeighborAnchor = self.topAnchor
                }
                
                let leftNeighborAnchor: NSLayoutXAxisAnchor
                if let cellView = cellViewAt(Coordinate(x: x - 1, y: y)) {
                    leftNeighborAnchor = cellView.rightAnchor
                } else {
                    leftNeighborAnchor = self.leftAnchor
                }
                
                let cellView = cellViewAt(Coordinate(x: x, y: y))!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])
                
                if y == Board.height - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if x == Board.width - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }
        
        reset()
        
        for y in (0..<Board.height) {
            for x in (0..<Board.width) {
                let coordinate = Coordinate(x: x, y: y)
                let cellView: CellView = cellViewAt(coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }
    
    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset() {
        for y in  (0..<Board.height) {
            for x in (0..<Board.width) {
                setDisk(nil, at: Coordinate(x: x, y: y), animated: false)
            }
        }
        
        setDisk(.light, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2 - 1), animated: false)
        setDisk(.dark, at: Coordinate(x: Board.width / 2, y: Board.height / 2 - 1), animated: false)
        setDisk(.dark, at: Coordinate(x: Board.width / 2 - 1, y: Board.height / 2), animated: false)
        setDisk(.light, at: Coordinate(x: Board.width / 2, y: Board.height / 2), animated: false)
    }
    
    private func cellViewAt(_ coordinate: Coordinate) -> CellView? {
        guard (0..<Board.width).contains(coordinate.x) && (0..<Board.height).contains(coordinate.y) else { return nil }
        return cellViews[coordinate.y * Board.width + coordinate.x]
    }
    
    /// `x`, `y` で指定されたセルの状態を返します。
    /// セルにディスクが置かれていない場合、 `nil` が返されます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: セルにディスクが置かれている場合はそのディスクの値を、置かれていない場合は `nil` を返します。
    public func diskAt(_ coordinate: Coordinate) -> Disk? {
        cellViewAt(coordinate)?.disk
    }
    
    /// `x`, `y` で指定されたセルの状態を、与えられた `disk` に変更します。
    /// `animated` が `true` の場合、アニメーションが実行されます。
    /// アニメーションの完了通知は `completion` ハンドラーで受け取ることができます。
    /// - Parameter disk: セルに設定される新しい状態です。 `nil` はディスクが置かれていない状態を表します。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter animated: セルの状態変更を表すアニメーションを表示するかどうかを指定します。
    /// - Parameter completion: アニメーションの完了通知を受け取るハンドラーです。
    ///     `animated` に `false` が指定された場合は状態が変更された後で即座に同期的に呼び出されます。
    ///     ハンドラーが受け取る `Bool` 値は、 `UIView.animate()`  等に準じます。
    public func setDisk(_ disk: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(coordinate) else {
            preconditionFailure() // FIXME: Add a message.
        }
        cellView.setDisk(disk, animated: animated, completion: completion)
    }

    func setDisk(placeType: PlaceType, at coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(coordinate) else {
            preconditionFailure() // FIXME: Add a message.
        }
        cellView.setDisk(placeType: placeType, animated: true, completion: completion)
    }

    /// `x`, `y` で指定されたセルに `disk` を置きます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter isAnimated: ディスクを置いたりひっくり返したりするアニメーションを表示するかどうかを指定します。
    /// - Parameter completion: アニメーション完了時に実行されるクロージャです。
    ///     このクロージャは値を返さず、アニメーションが完了したかを示す真偽値を受け取ります。
    ///     もし `animated` が `false` の場合、このクロージャは次の run loop サイクルの初めに実行されます。
    /// - Throws: もし `disk` を `x`, `y` で指定されるセルに置けない場合、 `DiskPlacementError` を `throw` します。
    func placeDisk(diskCoordinates: [Coordinate], placeTypes: [PlaceType], disk: Disk, at coordinate: Coordinate, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) throws {

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
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.setDisk(disk, at: coordinate, animated: false)
                for coordinate in diskCoordinates {
                    self.setDisk(disk, at: coordinate, animated: false)
                }
                completion?(true)
            }
        }
    }

    /// `coordinates` で指定されたセルに、アニメーションしながら順番に `disk` を置く。
    /// `coordinates` から先頭の座標を取得してそのセルに `disk` を置き、
    /// 残りの座標についてこのメソッドを再帰呼び出しすることで処理が行われる。
    /// すべてのセルに `disk` が置けたら `completion` ハンドラーが呼び出される。
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == Coordinate
    {
        guard let coordinate = coordinates.first else {
            completion(true)
            return
        }

        let animationCanceller = self.animationCanceller!
        setDisk(disk, at: coordinate, animated: true) { [weak self] isFinished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if isFinished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for coordinate in coordinates {
                    self.setDisk(disk, at: coordinate, animated: false)
                }
                completion(false)
            }
        }
    }

    /// "Computer" が選択されている場合のプレイヤーの行動を決定します。
    func playTurnOfComputer(turn: Disk, coordinate: Coordinate, diskCoordinates: [Coordinate], placeTypes: [PlaceType], completion: (() -> Void)? = nil) {
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            completion?()
            self.playerCancellers[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            try! self.placeDisk(diskCoordinates: diskCoordinates, placeTypes: placeTypes, disk: turn, at: coordinate, animated: true) { isFinished in
                if isFinished {
                    completion?()
                }
            }
        }

        playerCancellers[turn] = canceller
    }
}

public protocol BoardViewDelegate: AnyObject {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate)
}

private class CellSelectionAction: NSObject {
    private weak var boardView: BoardView?
    let coordinate: Coordinate

    init(boardView: BoardView, coordinate: Coordinate) {
        self.boardView = boardView
        self.coordinate = coordinate
    }
    
    @objc func selectCell() {
        guard let boardView = boardView else { return }
        boardView.delegate?.boardView(boardView, didSelectCellAt: coordinate)
    }
}
