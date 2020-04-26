import UIKit

protocol BoardViewDelegate: AnyObject {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate)
}

public class BoardView: UIView {

    weak var delegate: BoardViewDelegate?

    private var cellViews = [CellView]()
    private var actions = [CellSelectionAction]()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setUp(lines: [[BoardState]]) {
        self.backgroundColor = UIColor(named: "DarkColor")!

        let cellViews: [CellView] = lines.reduce(into: [CellView](), { result, line in
            for squire in line {
                let cellView = CellView()
                cellView.translatesAutoresizingMaskIntoConstraints = false
                result.append(cellView)
            }
        })

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
        
        for y in 0..<Board.yCount {
            for x in 0..<Board.xCount {

                let topNeighborAnchor: NSLayoutYAxisAnchor = {
                    if let cellView = cellViewAt(DiskCoordinate(x: x, y: y - 1)) {
                        return cellView.bottomAnchor
                    } else {
                        return topAnchor
                    }
                }()

                let leftNeighborAnchor: NSLayoutXAxisAnchor = {
                    if let cellView = cellViewAt(DiskCoordinate(x: x - 1, y: y)) {
                        return cellView.rightAnchor
                    } else {
                        return leftAnchor
                    }
                }()


                let lineWidth: CGFloat = 2
                let cellView = cellViewAt(DiskCoordinate(x: x, y: y))!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])
                
                if y == Board.yCount - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if x == Board.xCount - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }
        
        reset()
        
        for y in 0..<Board.yCount {
            for x in 0..<Board.xCount {
                let coordinate = DiskCoordinate(x: x, y: y)
                let cellView = cellViewAt(coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }

    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset() {
        for y in 0..<Board.yCount {
            for x in 0..<Board.xCount {
                setDisk(nil, at: DiskCoordinate(x: x, y: y), animated: false)
            }
        }

        let initialBoardStates: [BoardState] = [
            BoardState(disk: .light, coordinate: DiskCoordinate(x: Board.xCount / 2 - 1, y: Board.yCount / 2 - 1)),
            BoardState(disk: .dark, coordinate: DiskCoordinate(x: Board.xCount / 2, y: Board.yCount / 2 - 1)),
            BoardState(disk: .dark, coordinate: DiskCoordinate(x: Board.xCount / 2 - 1, y: Board.yCount / 2)),
            BoardState(disk: .light, coordinate: DiskCoordinate(x: Board.xCount / 2, y: Board.yCount / 2))
        ]

        initialBoardStates.forEach({
            setDisk($0.disk, at: $0.coordinate, animated: false)
        })
    }
    
    private func cellViewAt(_ coordinate: DiskCoordinate) -> CellView? {
        guard (0..<Board.xCount).contains(coordinate.x) && (0..<Board.yCount).contains(coordinate.y) else { return nil }
        return cellViews[coordinate.y * Board.xCount + coordinate.x]
    }
    
    /// `x`, `y` で指定されたセルの状態を返します。
    /// セルにディスクが置かれていない場合、 `nil` が返されます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: セルにディスクが置かれている場合はそのディスクの値を、置かれていない場合は `nil` を返します。
    func diskAt(_ coordinate: DiskCoordinate) -> Disk? {
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
    func setDisk(_ disk: Disk?, at coordinate: DiskCoordinate, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(coordinate) else {
            preconditionFailure() // FIXME: Add a message.
        }
        cellView.setDisk(disk, animated: animated, completion: completion)
    }

    func getBoardStates() -> [[BoardState]] {
        var result = [[BoardState]]()
        for y in 0..<Board.yCount {
            var boardStatesInLine = [BoardState]()
            for x in 0..<Board.xCount {
                let coordinate = DiskCoordinate(x: x, y: y)
                let disk = diskAt(coordinate)
                boardStatesInLine.append(BoardState(disk: disk, coordinate: coordinate))
            }
            result.append(boardStatesInLine)
        }
        return result
    }
}

private class CellSelectionAction: NSObject {
    private weak var boardView: BoardView?
    let coordinate: DiskCoordinate
    
    init(boardView: BoardView, coordinate: DiskCoordinate) {
        self.boardView = boardView
        self.coordinate = coordinate
    }
    
    @objc func selectCell() {
        guard let boardView = boardView else { return }
        boardView.delegate?.boardView(boardView, didSelectCellAt: coordinate)
    }
}
