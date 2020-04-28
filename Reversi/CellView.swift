import UIKit

public class CellView: UIView {
    private let button = UIButton()
    private let diskView = DiskView()
    
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
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        button.frame = bounds
        diskView.layout(disk, cellSize: bounds.size)
    }

    func setDisk(_ newDisk: Disk?, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        let oldDisk = self.disk
        self.disk = newDisk
        if animated {
            switch (oldDisk, newDisk) {
            case (.none, .none):
                completion?(true)
            case (.none, .some(let newDisk)):
                diskView.configure(disk: newDisk)
                animateSetDisk(newDisk, completion: completion)
            case (.some, .none):
                animateSetDisk(completion: completion)
            case (.some, .some(let newDisk)):
                flipAnimateSetDisk(newDisk, completion: completion)
            }
        } else {
            if let newDisk = newDisk {
                diskView.configure(disk: newDisk)
            }
            completion?(true)
            setNeedsLayout()
        }
    }
    
    private func animateSetDisk(_ newDisk: Disk? = nil, completion: ((Bool) -> Void)?) {
        self.disk = newDisk
        let animationDuration: TimeInterval = 0.25
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.diskView.layout(newDisk, cellSize: self.bounds.size)
        }, completion: { finished in
            completion?(finished)
        })
    }

    private func flipAnimateSetDisk(_ newDisk: Disk, completion: ((Bool) -> Void)?) {
        self.disk = newDisk
        let animationDuration: TimeInterval = 0.25
        UIView.animate(withDuration: animationDuration / 2, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            guard let self = self else { return }
            self.diskView.layout(newDisk, cellSize: self.bounds.size)
           }, completion: { [weak self] finished in
               guard let self = self else { return }
//               if self.diskView.disk == newDisk { // TODO: これが不要か判断
//                   completion?(finished)
//               }
               self.diskView.configure(disk: newDisk)
               UIView.animate(withDuration: animationDuration / 2, animations: {
                self.diskView.layout(newDisk, cellSize: self.bounds.size)
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
