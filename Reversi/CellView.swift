import UIKit

public class CellView: UIView {
    private let button: UIButton = UIButton()
    private let diskView: DiskView = DiskView()
    
    private var currentDisk: Disk?
    
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
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        button.frame = bounds
        layoutDiskView(disk: currentDisk)
    }
    
    private func layoutDiskView(disk: Disk?) {
        let cellSize = bounds.size
        let diskDiameter = Swift.min(cellSize.width, cellSize.height) * 0.8
        let diskSize: CGSize
        if currentDisk == nil || diskView.disk == currentDisk {
            diskSize = CGSize(width: diskDiameter, height: diskDiameter)
        } else {
            diskSize = CGSize(width: 0, height: diskDiameter)
        }
        diskView.frame = CGRect(
            origin: CGPoint(x: (cellSize.width - diskSize.width) / 2, y: (cellSize.height - diskSize.height) / 2),
            size: diskSize
        )
        diskView.alpha = currentDisk == nil ? 0.0 : 1.0
    }
    
    func setDisk(_ newDisk: Disk?, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        let beforeDisk: Disk? = currentDisk
        self.currentDisk = newDisk
        if animated {
            switch (beforeDisk, newDisk) {
            case (.none, .none):
                completion?(true)
            case (.none, .some(let animationDisk)):
                diskView.configure(disk: animationDisk)
                animateLayoutDiskView(disk: newDisk, completion: completion)
            case (.some, .none):
                animateLayoutDiskView(disk: newDisk, completion: completion)
            case (.some, .some(let newDisk)):
                animateLayoutDiskView2(newDisk: newDisk, completion: completion)
            }
        } else {
            if let newDisk = newDisk {
                diskView.configure(disk: newDisk)
            }
            completion?(true)
            setNeedsLayout()
        }
    }

    func animateLayoutDiskView(disk: Disk?, completion: ((Bool) -> Void)?) {
        let animationDuration: TimeInterval = 0.25
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            self?.layoutDiskView(disk: disk)
        }, completion: { finished in
            completion?(finished)
        })
    }

    func animateLayoutDiskView2(newDisk: Disk, completion: ((Bool) -> Void)?) {
        let animationDuration: TimeInterval = 0.25
        UIView.animate(withDuration: animationDuration / 2, delay: 0, options: .curveEaseOut, animations: { [weak self] in
               self?.layoutDiskView(disk: newDisk)
           }, completion: { [weak self] finished in
               guard let self = self else { return }
               if self.diskView.disk == newDisk {
                   completion?(finished)
               }
//               guard let newDisk = newDisk else {
//                   completion?(finished)
//                   return
//               }
               self.diskView.configure(disk: newDisk)
               UIView.animate(withDuration: animationDuration / 2, animations: { [weak self] in
                   self?.layoutDiskView(disk: newDisk)
               }, completion: { finished in
                   completion?(finished)
               })
           })
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
