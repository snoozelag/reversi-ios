import UIKit

public class CellView: UIView {
    private let button: UIButton = UIButton()
    let diskView: DiskView = DiskView()
    
    private var disk: Disk?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    private func setUp() {
        do { // button
            button.translatesAutoresizingMaskIntoConstraints = false
            do { // backgroundImage
                UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
                defer { UIGraphicsEndImageContext() }
                
                let color: UIColor = UIColor(named: "CellColor")!
                color.set()
                UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
                
                let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()!
                button.setBackgroundImage(backgroundImage, for: .normal)
                button.setBackgroundImage(backgroundImage, for: .disabled)
            }
            self.addSubview(button)
        }

        do { // diskView
            diskView.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(diskView)
        }

        setNeedsLayout()
    }

    public func setDisk(after: Disk?, before: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Coordinate, Bool) -> Void)? = nil) {
        self.disk = after
        diskView.setDisk(after: after, before: before, at: coordinate, animated: animated, completion: completion)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        
        button.frame = bounds
        diskView.layout(disk: self.disk)
    }
    
    public func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        button.addTarget(target, action: action, for: controlEvents)
    }
    
    public func removeTarget(_ target: Any?, action: Selector?, for controlEvents: UIControl.Event) {
        button.removeTarget(target, action: action, for: controlEvents)
    }
    
    public func actions(forTarget target: Any?, forControlEvent controlEvent: UIControl.Event) -> [String]? {
        button.actions(forTarget: target, forControlEvent: controlEvent)
    }
    
    public var allTargets: Set<AnyHashable> {
        button.allTargets
    }
    
    public var allControlEvents: UIControl.Event {
        button.allControlEvents
    }
}
