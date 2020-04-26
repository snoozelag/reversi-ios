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

    /// linesには初期状態の盤面状態を渡します
    func setUp(lines: [[SquireState]]) {
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

        for line in lines {
            for squire in line {
                let topNeighborAnchor: NSLayoutYAxisAnchor = {
                    if let cellView = cellViewAt(DiskCoordinate(x: squire.coordinate.x, y: squire.coordinate.y - 1)) {
                        return cellView.bottomAnchor
                    } else {
                        return topAnchor
                    }
                }()

                let leftNeighborAnchor: NSLayoutXAxisAnchor = {
                    if let cellView = cellViewAt(DiskCoordinate(x: squire.coordinate.x - 1, y: squire.coordinate.y)) {
                        return cellView.rightAnchor
                    } else {
                        return leftAnchor
                    }
                }()


                let lineWidth: CGFloat = 2
                let cellView = cellViewAt(DiskCoordinate(x: squire.coordinate.x, y: squire.coordinate.y))!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])

                if squire.coordinate.y == Board.yCount - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if squire.coordinate.x == Board.xCount - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }

        setDisks(lines: lines)

        for line in lines {
            for squire in line {
                let cellView = cellViewAt(squire.coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: squire.coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }

    /// 盤をセット
    func setDisks(lines: [[SquireState]]) {
        for line in lines {
            for squire in line {
                setDisk(squire: squire, animated: false)
            }
        }
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
    func setDisk(squire: SquireState, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(squire.coordinate) else {
            preconditionFailure() // FIXME: Add a message.
        }
        cellView.setDisk(squire.disk, animated: animated, completion: completion)
    }

    func getLines(board: Board) -> [[SquireState]] {
        var result = [[SquireState]]()
        for y in 0..<board.lines.count {
            var boardStatesInLine = [SquireState]()
            for x in 0..<board.lines[0].count {
                let coordinate = DiskCoordinate(x: x, y: y)
                let disk = diskAt(coordinate)
                boardStatesInLine.append(SquireState(disk: disk, coordinate: coordinate))
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
