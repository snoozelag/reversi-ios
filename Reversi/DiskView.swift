import UIKit

public class DiskView: UIView {
    /// このビューが表示するディスクの色を決定します。
    private var disk: Disk? = .dark {
        didSet { setNeedsDisplay() }
    }

    func configure(disk: Disk?) {
        self.disk = disk
    }

    func layout(disk: Disk?) {
        guard let superviewSize = superview?.bounds.size else { return }
        let diskDiameter = Swift.min(superviewSize.width, superviewSize.height) * 0.8
        let diskSize: CGSize = {
            if disk == nil || self.disk == disk {
                return CGSize(width: diskDiameter, height: diskDiameter)
            } else {
                return CGSize(width: 0, height: diskDiameter)
            }
        }()
        frame = CGRect(
            origin: CGPoint(x: (superviewSize.width - diskSize.width) / 2, y: (superviewSize.height - diskSize.height) / 2),
            size: diskSize
        )
        alpha = (disk == nil) ? 0.0 : 1.0
    }

    public func setDisk(after: Disk?, before: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Coordinate, Bool) -> Void)? = nil) {
        if animated {
            switch (before, after) {
            case (.none, .none):
                completion?(coordinate, true)
            case (.none, .some(let animationDisk)):
                configure(disk: animationDisk)
                fallthrough
            case (.some, .none):
                let animationDuration: TimeInterval = 0.25
                UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn, animations: {
                    self.layout(disk: after)
                }, completion: { finished in
                    completion?(coordinate, finished)
                })
            case (.some(let before), .some(let after)):
                let animationDuration: TimeInterval = 0.25
                UIView.animate(withDuration: animationDuration / 2, delay: 0, options: .curveEaseOut, animations: {
                    self.layout(disk: after)
                }, completion: { finished in
                    if before == after {
                        completion?(coordinate, finished)
                    }
                    self.configure(disk: after)
                    UIView.animate(withDuration: animationDuration / 2, animations: {
                        self.layout(disk: after)
                    }, completion: { finished in
                        completion?(coordinate, finished)
                    })
                })
            }
        } else {
            self.configure(disk: after)
            self.layout(disk: after)
            completion?(coordinate, true)
            setNeedsLayout()
        }
    }
    
    /// Interface Builder からディスクの色を設定するためのプロパティです。 `"dark"` か `"light"` の文字列を設定します。
    @IBInspectable public var name: String? {
        get { disk?.name ?? Disk.dark.name }
        set { disk = .init(name: newValue ?? Disk.dark.name) }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    override public func draw(_ rect: CGRect) {
        guard let disk = disk else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(disk.cgColor)
        context.fillEllipse(in: bounds)
    }
}

extension Disk {
    fileprivate var uiColor: UIColor {
        switch self {
        case .dark: return UIColor(named: "DarkColor")!
        case .light: return UIColor(named: "LightColor")!
        }
    }
    
    fileprivate var cgColor: CGColor {
        uiColor.cgColor
    }
    
    fileprivate var name: String {
        switch self {
        case .dark: return "dark"
        case .light: return "light"
        }
    }
    
    fileprivate init(name: String) {
        switch name {
        case Disk.dark.name:
            self = .dark
        case Disk.light.name:
            self = .light
        default:
            preconditionFailure("Illegal name: \(name)")
        }
    }
}
