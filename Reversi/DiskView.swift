import UIKit

class DiskView: UIView {

    private var disk: Disk = .dark

    func configure(disk: Disk) {
        self.disk = disk
        setNeedsDisplay()
    }
    
    /// Interface Builder からディスクの色を設定するためのプロパティです。 `"dark"` か `"light"` の文字列を設定します。
    @IBInspectable var name: String {
        get { disk.name }
        set { disk = .init(name: newValue) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(disk.cgColor)
        context.fillEllipse(in: bounds)
    }

    func layout(_ newDisk: Disk?, cellSize: CGSize) {
        let diskDiameter = Swift.min(cellSize.width, cellSize.height) * 0.8
        let diskSize: CGSize = {
            if newDisk == nil || self.disk == newDisk {
                return CGSize(width: diskDiameter, height: diskDiameter)
            } else {
                return CGSize(width: 0, height: diskDiameter)
            }
        }()
        frame = CGRect(
            origin: CGPoint(x: (cellSize.width - diskSize.width) / 2, y: (cellSize.height - diskSize.height) / 2),
            size: diskSize
        )
        alpha = (newDisk == nil) ? 0.0 : 1.0
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
