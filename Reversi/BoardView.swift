import UIKit

private let lineWidth: CGFloat = 2

public class BoardView: UIView {
    private var cellViews: [CellView] = []
    private var actions: [CellSelectionAction] = []

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
        let board = Board() // 初期化用
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
        
        for line in board.lines {
            for squire in line {
                let cellView: CellView = cellViewAt(squire.coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: squire.coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }

    func configure(board: Board) {
        for line in board.lines {
            for squire in line {
                let cellView = cellViewAt(squire.coordinate)!
                cellView.setDisk(after: squire.disk, before: nil, at: squire.coordinate, animated: false)
            }
        }
    }
    
    private func cellViewAt(_ coordinate: Coordinate) -> CellView? {
        guard (0..<Board.width).contains(coordinate.x) && (0..<Board.height).contains(coordinate.y) else { return nil }
        return cellViews[coordinate.y * Board.width + coordinate.x]
    }

    public func setDisks<C: Collection>(after: Disk?, at squires: C, animated: Bool, flippedHandler: ((Coordinate, Bool) -> Void)? = nil, completion: (() -> Void)? = nil) where C.Element == Squire {

        guard let squire = squires.first else {
            completion?()
            return
        }

        let cellView = cellViewAt(squire.coordinate)!
        cellView.setDisk(after: after, before: squire.disk, at: squire.coordinate, animated: animated) { [weak self] coordinate, isFinished in
            guard let self = self else { return }

            if isFinished {
                flippedHandler?(coordinate, isFinished)
                self.setDisks(after: after, at: squires.dropFirst(), animated: animated, flippedHandler: flippedHandler, completion: completion)
            } else {
                for squire in squires {
                    cellView.setDisk(after: after, before: squire.disk, at: squire.coordinate, animated: false)
                }
                completion?()
            }
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
