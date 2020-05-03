public enum Disk: CaseIterable {
    case dark
    case light

    var viewIndex: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}

extension Disk: Hashable {}

extension Disk {
    
    /// 自身の値を反転させた値（ `.dark` なら `.light` 、 `.light` なら `.dark` ）を返します。
    public var flipped: Disk {
        switch self {
        case .dark: return .light
        case .light: return .dark
        }
    }
    
    /// 自身の値を、現在の値が `.dark` なら `.light` に、 `.light` なら `.dark` に反転させます。
    public mutating func flip() {
        self = flipped
    }
}
