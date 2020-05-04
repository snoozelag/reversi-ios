import UIKit

private let lineWidth: CGFloat = 2

public class BoardView: UIView {
    private var cellViews: [CellView] = []
    private var actions: [CellSelectionAction] = []
    private(set) var board = Board()

    /// セルがタップされたときの挙動を移譲するためのオブジェクトです。
    public weak var delegate: BoardViewDelegate?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    private func setUp() {
        self.backgroundColor = UIColor(named: "DarkColor")!
        
        let cellViews: [CellView] = (0 ..< (Board.width * Board.height)).map { _ in
            let cellView = CellView()
            cellView.translatesAutoresizingMaskIntoConstraints = false
            return cellView
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
        
        for line in board.lines {
            for squire in line {
                let coordinate = squire.coordinate
                let topNeighborAnchor: NSLayoutYAxisAnchor
                if let cellView = cellViewAt(Coordinate(x: coordinate.x, y: coordinate.y - 1)) {
                    topNeighborAnchor = cellView.bottomAnchor
                } else {
                    topNeighborAnchor = self.topAnchor
                }
                
                let leftNeighborAnchor: NSLayoutXAxisAnchor
                if let cellView = cellViewAt(Coordinate(x: coordinate.x - 1, y: coordinate.y)) {
                    leftNeighborAnchor = cellView.rightAnchor
                } else {
                    leftNeighborAnchor = self.leftAnchor
                }
                
                let cellView = cellViewAt(Coordinate(x: coordinate.x, y: coordinate.y))!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])
                
                if coordinate.y == Board.height - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if coordinate.x == Board.width - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }
        
        reset()
        
        for line in board.lines {
            for squire in line {
                let cellView: CellView = cellViewAt(squire.coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: squire.coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }
    
    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset() {
        for line in board.lines {
            for squire in line {
                setDisk(nil, at: squire.coordinate, animated: false)
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

    public func setDisk(_ disk: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(coordinate) else {
            preconditionFailure() // FIXME: Add a message.
        }
        let before = board.disk(at: coordinate)
        board.setDisk(disk, at: coordinate)
        setDiskForCellView(cellView, after: disk, before: before, animated: animated, completion: completion)
    }

    public func setDiskForCellView(_ cellView: CellView, after: Disk?, before: Disk?, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        cellView.configure(disk: after)
        if animated {
            switch (before, after) {
            case (.none, .none):
                completion?(true)
            case (.none, .some(let animationDisk)):
                cellView.diskView.configure(disk: animationDisk)
                fallthrough
            case (.some, .none):
                let animationDuration: TimeInterval = 0.25
                UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn, animations: { [weak self] in
                    cellView.diskView.layout(cellSize: cellView.bounds.size, cellDisk: after)
                }, completion: { finished in
                    completion?(finished)
                })
            case (.some(let before), .some(let after)):
                let animationDuration: TimeInterval = 0.25
                UIView.animate(withDuration: animationDuration / 2, delay: 0, options: .curveEaseOut, animations: { [weak self] in
                    cellView.diskView.layout(cellSize: cellView.bounds.size, cellDisk: after)
                }, completion: { [weak self] finished in
                    guard let self = self else { return }
                    if before == after {
                        completion?(finished)
                    }
                    cellView.diskView.configure(disk: after)
                    UIView.animate(withDuration: animationDuration / 2, animations: { [weak self] in
                        cellView.diskView.layout(cellSize: cellView.bounds.size, cellDisk: after)
                    }, completion: { finished in
                        completion?(finished)
                    })
                })
            }
        } else {
            if let after = after {
                cellView.diskView.configure(disk: after)
            }
            completion?(true)
            setNeedsLayout()
        }
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

public class Board {
    var lines = [[Squire]]()

    /// 盤の幅（ `8` ）を表します。
    public static let width: Int = 8

    /// 盤の高さ（ `8` ）を返します。
    public static let height: Int = 8

    init() {
        self.lines = {
            var result = [[Squire]]()
            for y in 0..<Self.height {
                var line = [Squire]()
                for x in 0..<Self.width {
                    line.append(Squire(disk: nil, coordinate: Coordinate(x: x, y: y)))
                }
                result.append(line)
            }
            return result
        }()
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        guard (0..<Board.width) ~= coordinate.x && (0..<Board.height) ~= coordinate.y else { return }
        lines[coordinate.y][coordinate.x].disk = disk
    }

    func disk(at coordinate: Coordinate) -> Disk? {
        guard (0..<Board.width) ~= coordinate.x && (0..<Board.height) ~= coordinate.y else { return nil }
        return lines[coordinate.y][coordinate.x].disk
    }
}

public struct Squire {
    var disk: Disk?
    var coordinate: Coordinate
}
