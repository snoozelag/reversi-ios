import UIKit

protocol BoardViewDelegate: AnyObject {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: DiskCoordinate)
}

public class BoardView: UIView {

    private var cellViews = [CellView]()
    private var actions = [CellSelectionAction]()
    private var boardDisks: [[Disk?]] = {
        return Array<[Disk?]>(repeating: Array<Disk?>(repeating: nil, count: xCount), count: yCount)
    }()
    
    /// 盤の幅（ `8` ）を表します。
    static let xCount: Int = 8
    
    /// 盤の高さ（ `8` ）を返します。
    static let yCount: Int = 8
    
    /// セルがタップされたときの挙動を移譲するためのオブジェクトです。
    weak var delegate: BoardViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    func countDisks(of side: Disk) -> Int {
        var count = 0

        for y in 0..<Self.yCount {
            for x in 0..<Self.xCount {
                if diskAt(DiskCoordinate(x: x, y: y)) == side {
                    count +=  1
                }
            }
        }

        return count
    }
    
    private func setUp() {
        self.backgroundColor = UIColor(named: "DarkColor")!
        
        let cellViews: [CellView] = (0 ..< (Self.xCount * Self.yCount)).map { _ in
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
        
        for y in 0..<Self.yCount {
            for x in 0..<Self.xCount {
                let topNeighborAnchor: NSLayoutYAxisAnchor
                if let cellView = cellViewAt(DiskCoordinate(x: x, y: y - 1)) {
                    topNeighborAnchor = cellView.bottomAnchor
                } else {
                    topNeighborAnchor = self.topAnchor
                }
                
                let leftNeighborAnchor: NSLayoutXAxisAnchor
                if let cellView = cellViewAt(DiskCoordinate(x: x - 1, y: y)) {
                    leftNeighborAnchor = cellView.rightAnchor
                } else {
                    leftNeighborAnchor = self.leftAnchor
                }

                let lineWidth: CGFloat = 2
                let cellView = cellViewAt(DiskCoordinate(x: x, y: y))!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])
                
                if y == Self.yCount - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if x == Self.xCount - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }
        
        reset()
        
        for y in 0..<Self.yCount {
            for x in 0..<Self.xCount {
                let coordinate = DiskCoordinate(x: x, y: y)
                let cellView: CellView = cellViewAt(coordinate)!
                let action = CellSelectionAction(boardView: self, coordinate: coordinate)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }
    
    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset() {
        for y in 0..<Self.yCount {
            for x in 0..<Self.xCount {
                setDisk(nil, at: DiskCoordinate(x: x, y: y), animated: false)
            }
        }
        
        setDisk(.light, at: DiskCoordinate(x: Self.xCount / 2 - 1, y: Self.yCount / 2 - 1), animated: false)
        setDisk(.dark, at: DiskCoordinate(x: Self.xCount / 2, y: Self.yCount / 2 - 1), animated: false)
        setDisk(.dark, at: DiskCoordinate(x: Self.xCount / 2 - 1, y: Self.yCount / 2), animated: false)
        setDisk(.light, at: DiskCoordinate(x: Self.xCount / 2, y: Self.yCount / 2), animated: false)
    }
    
    private func cellViewAt(_ coordinate: DiskCoordinate) -> CellView? {
        guard (0..<Self.xCount).contains(coordinate.x) && (0..<Self.yCount).contains(coordinate.y) else { return nil }
        return cellViews[coordinate.y * Self.xCount + coordinate.x]
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

    func getBoardStatesString() -> String {
        var output = ""
        for y in 0..<Self.yCount {
            for x in 0..<Self.xCount {
                if let side = diskAt(DiskCoordinate(x: x, y: y)) {
                    output += (side == .dark) ? GameIO.darkSymbol : GameIO.lightSymbol
                } else {
                    let noneSymbol = "-"
                    output += noneSymbol
                }
            }
            output += "\n"
        }
        return output
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
