import UIKit

protocol BoardViewDelegate: AnyObject {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate)
}

public class BoardView: UIView {

    weak var delegate: BoardViewDelegate?

    private var cellViews = [CellView]()
    private var actions = [CellSelectionAction]()

    var animationCanceller: Canceller?
    var isAnimating: Bool { animationCanceller != nil }
    var darkCanceller: Canceller?
    var lightCanceller: Canceller?

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

    func cancelAnimations() {
        animationCanceller?.cancel()
        animationCanceller = nil
        darkCanceller?.cancel()
        darkCanceller = nil
        lightCanceller?.cancel()
        lightCanceller = nil
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
    
    /// `x`, `y` で指定されたセルの状態を、与えられた `disk` に変更します。
    /// `animated` が `true` の場合、アニメーションが実行されます。
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
                let disk = board.squireAt(coordinate)!.disk
                boardStatesInLine.append(SquireState(disk: disk, coordinate: coordinate))
            }
            result.append(boardStatesInLine)
        }
        return result
    }


    /// `coordinates` で指定されたセルに、アニメーションしながら順番に `disk` を置く。
    /// `coordinates` から先頭の座標を取得してそのセルに `disk` を置き、
    /// 残りの座標についてこのメソッドを再帰呼び出しすることで処理が行われる。
    /// すべてのセルに `disk` が置けたら `completion` ハンドラーが呼び出される。
    func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == DiskCoordinate
    {
        guard let coordinate = coordinates.first else {
            completion(true)
            return
        }
        let animationCanceller = self.animationCanceller!

        let squire = SquireState(disk: disk, coordinate: coordinate)
        setDisk(squire: squire, animated: true) { [weak self] isFinished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if isFinished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for coordinate in coordinates {
                    self.setDisk(squire: SquireState(disk: disk, coordinate: coordinate), animated: false)
                }
                completion(false)
            }
        }
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
